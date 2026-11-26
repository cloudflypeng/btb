import SwiftUI

#if os(macOS)
import AppKit
typealias BtbPlatformImage = NSImage
#else
import UIKit
typealias BtbPlatformImage = UIImage
#endif

@MainActor
final class BtbImageCache {
    static let shared = BtbImageCache()

    private let cache = NSCache<NSURL, BtbPlatformImage>()
    private var tasks: [URL: Task<BtbPlatformImage?, Never>] = [:]

    private init() {
        cache.countLimit = 240
    }

    func image(for url: URL) -> BtbPlatformImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> BtbPlatformImage? {
        if let image = image(for: url) {
            return image
        }
        if let task = tasks[url] {
            return await task.value
        }

        let task = Task { () -> BtbPlatformImage? in
            guard let (data, _) = try? await URLSession.shared.data(from: url) else {
                return nil
            }
            #if os(macOS)
            return NSImage(data: data)
            #else
            return UIImage(data: data)
            #endif
        }
        tasks[url] = task
        let image = await task.value
        tasks[url] = nil

        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }
        return image
    }
}

typealias ImageCache = BtbImageCache

extension Image {
    init(btbImage: BtbPlatformImage) {
        #if os(macOS)
        self.init(nsImage: btbImage)
        #else
        self.init(uiImage: btbImage)
        #endif
    }
}

struct BtbRemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var placeholderIcon: String? = nil
    var showsLoadingIndicator: Bool = false

    @Environment(\.colorScheme) private var scheme
    @State private var image: BtbPlatformImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(btbImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(AppTheme.chip(scheme))
                    .overlay { placeholder }
            }
        }
        .clipped()
        .animation(BtbMotion.curve(BtbMotion.fast), value: image != nil)
        .task(id: url) { await load() }
        .accessibilityHidden(true)
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
        failed = false
        guard let url else {
            image = nil
            failed = true
            return
        }
        if let cached = BtbImageCache.shared.image(for: url) {
            image = cached
            return
        }
        image = nil
        let loaded = await BtbImageCache.shared.load(url)
        guard !Task.isCancelled else { return }
        image = loaded
        failed = loaded == nil
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
