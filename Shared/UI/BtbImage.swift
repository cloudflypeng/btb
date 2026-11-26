import ImageIO
import SwiftUI

#if os(macOS)
import AppKit
typealias BtbPlatformImage = NSImage
#else
import UIKit
typealias BtbPlatformImage = UIImage
#endif

// MARK: - Pipeline

/// Image pipeline:
/// 1. Request a server-side resized variant (`@{w}w.webp`) from Bilibili's image CDN.
/// 2. Decode off the main thread with ImageIO, downsampled to the target pixel size,
///    and force-decoded so the first draw never blocks scrolling.
/// 3. Two cache tiers: byte-limited in-memory LRU + on-disk cache (bounded, clearable).
@MainActor
final class BtbImageCache {
    static let shared = BtbImageCache()

    private let memory = NSCache<NSString, BtbPlatformImage>()
    private var tasks: [String: Task<BtbPlatformImage?, Never>] = [:]
    /// Latest key loaded for each source URL, so `image(for:)` can answer synchronously
    /// for callers that don't know the requested size (hero transitions).
    private var latestKey: [URL: String] = [:]

    private init() {
        memory.totalCostLimit = 96 * 1024 * 1024
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.memory.removeAllObjects() }
        }
        #endif
    }

    /// Any already-decoded image for this source URL, regardless of size.
    func image(for url: URL) -> BtbPlatformImage? {
        if let key = latestKey[url], let image = memory.object(forKey: key as NSString) {
            return image
        }
        return memory.object(forKey: Self.key(url, pixels: 0) as NSString)
    }

    func image(for url: URL, pixels: Int) -> BtbPlatformImage? {
        memory.object(forKey: Self.key(url, pixels: Self.bucket(pixels)) as NSString)
    }

    /// Loads `url`, downsampled so its longest side is about `pixels` (0 = original).
    func load(_ url: URL, pixels: Int = 0) async -> BtbPlatformImage? {
        let pixels = Self.bucket(pixels)
        let key = Self.key(url, pixels: pixels)
        if let image = memory.object(forKey: key as NSString) {
            return image
        }
        if let task = tasks[key] {
            return await task.value
        }

        let remote = Self.resizedURL(url, pixels: pixels)
        let task = Task.detached(priority: .userInitiated) { () -> BtbPlatformImage? in
            await BtbImagePipeline.fetch(remote, cacheKey: key, pixels: pixels)
        }
        tasks[key] = task
        let image = await task.value
        tasks[key] = nil

        if let image {
            memory.setObject(image, forKey: key as NSString, cost: Self.cost(of: image))
            latestKey[url] = key
        }
        return image
    }

    /// Warm both caches for upcoming items. Low priority and fire-and-forget.
    func prefetch(_ urls: [URL], pixels: Int) {
        let pixels = Self.bucket(pixels)
        for url in urls {
            let key = Self.key(url, pixels: pixels)
            guard memory.object(forKey: key as NSString) == nil, tasks[key] == nil else { continue }
            Task(priority: .utility) { _ = await load(url, pixels: pixels) }
        }
    }

    func clearMemory() {
        memory.removeAllObjects()
        latestKey.removeAll()
    }

    // MARK: Helpers

    /// Round up to a small set of sizes so nearby layouts share cache entries.
    nonisolated static func bucket(_ pixels: Int) -> Int {
        guard pixels > 0 else { return 0 }
        for step in [96, 160, 240, 360, 480, 720, 960, 1280, 1920] where pixels <= step {
            return step
        }
        return 0
    }

    nonisolated static func key(_ url: URL, pixels: Int) -> String {
        "\(pixels)|\(url.absoluteString)"
    }

    /// Bilibili's image CDN (`*.hdslb.com`) supports `@{w}w.webp` suffixes.
    nonisolated static func resizedURL(_ url: URL, pixels: Int) -> URL {
        guard pixels > 0,
              let host = url.host, host.hasSuffix("hdslb.com"),
              !url.path.contains("@") else { return url }
        let ext = url.pathExtension.lowercased()
        guard ["jpg", "jpeg", "png", "webp"].contains(ext) else { return url }
        return URL(string: url.absoluteString + "@\(pixels)w.webp") ?? url
    }

    private static func cost(of image: BtbPlatformImage) -> Int {
        #if os(macOS)
        let rep = image.representations.first
        return (rep?.pixelsWide ?? 0) * (rep?.pixelsHigh ?? 0) * 4
        #else
        guard let cg = image.cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
        #endif
    }
}

typealias ImageCache = BtbImageCache

/// Off-main-thread fetch + decode + disk cache.
enum BtbImagePipeline {
    static let diskLimitBytes = 200 * 1024 * 1024

    static let directory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("BTBImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil // we keep our own disk cache of the resized bytes
        config.httpMaximumConnectionsPerHost = 8
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    static func fetch(_ url: URL, cacheKey: String, pixels: Int) async -> BtbPlatformImage? {
        let file = directory.appendingPathComponent(fileName(cacheKey))
        if let data = try? Data(contentsOf: file), let image = decode(data, pixels: pixels) {
            return image
        }
        guard let (data, response) = try? await session.data(from: url) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        guard let image = decode(data, pixels: pixels) else { return nil }
        try? data.write(to: file, options: .atomic)
        return image
    }

    /// ImageIO thumbnail decode: never materialises the full-size bitmap.
    static func decode(_ data: Data, pixels: Int) -> BtbPlatformImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        if pixels > 0 {
            options[kCGImageSourceThumbnailMaxPixelSize] = pixels
        } else if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let w = props[kCGImagePropertyPixelWidth] as? Int,
                  let h = props[kCGImagePropertyPixelHeight] as? Int {
            options[kCGImageSourceThumbnailMaxPixelSize] = max(w, h)
        }
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        #if os(macOS)
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        #else
        return UIImage(cgImage: cg)
        #endif
    }

    private static func fileName(_ key: String) -> String {
        // FNV-1a 64-bit: stable across launches (unlike Hasher).
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    // MARK: Disk maintenance

    static func diskUsageBytes() -> Int {
        files().reduce(0) { $0 + $1.size }
    }

    static func clearDisk() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Evict least-recently-modified files until under the limit.
    static func trimDisk() {
        var entries = files()
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > diskLimitBytes else { return }
        entries.sort { $0.date < $1.date }
        for entry in entries where total > diskLimitBytes * 8 / 10 {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    private static func files() -> [(url: URL, size: Int, date: Date)] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys
        )) ?? []
        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return (url, values?.fileSize ?? 0, values?.contentModificationDate ?? .distantPast)
        }
    }
}

extension Image {
    init(btbImage: BtbPlatformImage) {
        #if os(macOS)
        self.init(nsImage: btbImage)
        #else
        self.init(uiImage: btbImage)
        #endif
    }
}

// MARK: - Views

struct BtbRemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var placeholderIcon: String? = nil
    var showsLoadingIndicator: Bool = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale
    @State private var image: BtbPlatformImage?
    @State private var failed = false
    @State private var pixels = 0

    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.chip(scheme))
                .overlay { if image == nil { placeholder } }
            if let image {
                Image(btbImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            }
        }
        .clipped()
        .animation(BtbMotion.snappy, value: image != nil)
        .onGeometryChange(for: Int.self) { proxy in
            Int((max(proxy.size.width, proxy.size.height) * displayScale).rounded(.up))
        } action: { value in
            let bucket = BtbImageCache.bucket(value)
            if bucket != pixels { pixels = bucket }
        }
        .task(id: LoadKey(url: url, pixels: pixels)) { await load() }
        .accessibilityHidden(true)
    }

    private struct LoadKey: Equatable {
        let url: URL?
        let pixels: Int
    }

    @ViewBuilder
    private var placeholder: some View {
        if let placeholderIcon {
            if showsLoadingIndicator && !failed {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: placeholderIcon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }
        } else if showsLoadingIndicator && !failed {
            ProgressView()
                .controlSize(.small)
        }
    }

    private func load() async {
        // Wait for the first layout pass so we request the right size.
        guard pixels > 0 else { return }
        failed = false
        guard let url else {
            image = nil
            failed = true
            return
        }
        if let cached = BtbImageCache.shared.image(for: url, pixels: pixels) {
            image = cached
            return
        }
        // Keep a lower-res copy on screen while the right size loads (no flash).
        if image == nil, let any = BtbImageCache.shared.image(for: url) {
            image = any
        }
        let loaded = await BtbImageCache.shared.load(url, pixels: pixels)
        guard !Task.isCancelled else { return }
        if let loaded { image = loaded }
        failed = loaded == nil && image == nil
    }
}

struct BtbAvatar: View {
    let url: URL?
    var size: CGFloat = 32

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        BtbRemoteImage(
            url: url,
            placeholderIcon: "person.crop.circle.fill"
        )
        .frame(width: size, height: size)
        .background(AppTheme.chip(scheme))
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
        }
    }
}

// MARK: - Prefetch (A3)

extension View {
    /// When this card appears, warm the cover cache for the next `lookahead` items
    /// at this card's rendered width. Uniform feeds only need it on the card view.
    func prefetchCovers(
        _ items: [VideoItem],
        after current: VideoItem,
        lookahead: Int = 8
    ) -> some View {
        modifier(CoverPrefetchModifier(items: items, current: current, lookahead: lookahead))
    }
}

private struct CoverPrefetchModifier: ViewModifier {
    let items: [VideoItem]
    let current: VideoItem
    let lookahead: Int

    @Environment(\.displayScale) private var displayScale
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .onAppear {
                guard width > 0,
                      let index = items.firstIndex(where: { $0.bvid == current.bvid }) else { return }
                let upcoming = items.dropFirst(index + 1).prefix(lookahead).compactMap(\.coverURL)
                guard !upcoming.isEmpty else { return }
                BtbImageCache.shared.prefetch(Array(upcoming), pixels: Int(width * displayScale))
            }
    }
}
