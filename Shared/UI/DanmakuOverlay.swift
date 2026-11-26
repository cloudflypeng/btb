import AVFoundation
import CoreText
import QuartzCore
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DanmakuOverlay: View {
    let player: AVPlayer?
    let items: [DanmakuItem]
    let isEnabled: Bool
    let isPlaying: Bool
    var opacity: Double = 0.92
    var speed: Double = 1.0
    var fontScale: Double = 1.0

    var body: some View {
        if isEnabled, !items.isEmpty, let player {
            DanmakuLayerHost(
                player: player,
                items: items,
                isPlaying: isPlaying,
                opacity: opacity,
                speed: speed,
                fontScale: fontScale
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

#if os(iOS)
private struct DanmakuLayerHost: UIViewRepresentable {
    let player: AVPlayer
    let items: [DanmakuItem]
    let isPlaying: Bool
    let opacity: Double
    let speed: Double
    let fontScale: Double

    func makeUIView(context: Context) -> DanmakuDisplayView {
        let view = DanmakuDisplayView()
        view.apply(player: player, items: items, isPlaying: isPlaying, opacity: opacity, speed: speed, fontScale: fontScale)
        return view
    }

    func updateUIView(_ view: DanmakuDisplayView, context: Context) {
        view.apply(player: player, items: items, isPlaying: isPlaying, opacity: opacity, speed: speed, fontScale: fontScale)
    }

    static func dismantleUIView(_ view: DanmakuDisplayView, coordinator: ()) {
        view.stop()
    }
}

private final class DanmakuDisplayView: UIView {
    private let renderer = DanmakuRenderer()
    private var link: CADisplayLink?
    private var player: AVPlayer?
    private var isPlaying = false
    private var contentsScale: CGFloat = UIScreen.main.scale

#if DEBUG
    private var debugFrames = 0
    private var debugLastLog = CACurrentMediaTime()
    private lazy var debugFPSLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private var debugFPSEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-BTB_DANMAKU_FPS"), index + 1 < arguments.count {
            return arguments[index + 1] == "1"
        }
        return ProcessInfo.processInfo.environment["BTB_DANMAKU_FPS"] == "1"
            || arguments.contains("-DanmakuFPS")
    }
#endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        renderer.yAxisDown = true
        renderer.contentsScale = contentsScale
        layer.addSublayer(renderer.container)
#if DEBUG
        addSubview(debugFPSLabel)
        NSLayoutConstraint.activate([
            debugFPSLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            debugFPSLabel.topAnchor.constraint(equalTo: topAnchor, constant: 44),
            debugFPSLabel.heightAnchor.constraint(equalToConstant: 20),
            debugFPSLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
        ])
        debugFPSLabel.isHidden = !debugFPSEnabled
#endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        renderer.container.frame = bounds
        CATransaction.commit()
        renderer.render(at: currentPlayerTime, size: bounds.size)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            link?.invalidate()
            link = nil
            return
        }
        if let scale = window?.screen.scale {
            contentsScale = scale
            renderer.contentsScale = scale
        }
        updateDisplayLink()
        renderer.render(at: currentPlayerTime, size: bounds.size)
    }

    func apply(player: AVPlayer, items: [DanmakuItem], isPlaying: Bool, opacity: Double, speed: Double, fontScale: Double) {
        self.player = player
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            updateDisplayLink()
        }
        renderer.update(items: items, opacity: opacity, speed: speed, fontScale: fontScale)
        if !isPlaying {
            renderer.render(at: currentPlayerTime, size: bounds.size)
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    private var currentPlayerTime: Double {
        guard let seconds = player?.currentTime().seconds, seconds.isFinite else { return 0 }
        return seconds
    }

    private func updateDisplayLink() {
        guard isPlaying, window != nil else {
            link?.isPaused = true
            return
        }
        if link == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            displayLink.add(to: .main, forMode: .common)
            link = displayLink
        }
        link?.isPaused = false
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        guard isPlaying, let player else { return }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite else { return }
#if DEBUG
        let started = CACurrentMediaTime()
        renderer.render(at: seconds, size: bounds.size)
        logRenderCost(CACurrentMediaTime() - started)
        logDebugFPSIfNeeded()
#else
        renderer.render(at: seconds, size: bounds.size)
#endif
    }

#if DEBUG
    private var renderCostSum = 0.0
    private var renderCostMax = 0.0
    private var renderCostFrames = 0
    private var renderCostLoggedAt = CACurrentMediaTime()

    /// Renderer CPU time per frame, so the 120Hz budget can be checked
    /// without a profiler attached (`-BTB_DANMAKU_FPS 1`).
    private func logRenderCost(_ seconds: Double) {
        guard debugFPSEnabled else { return }
        renderCostSum += seconds
        renderCostMax = max(renderCostMax, seconds)
        renderCostFrames += 1
        let now = CACurrentMediaTime()
        guard now - renderCostLoggedAt >= 2, renderCostFrames > 0 else { return }
        let average = renderCostSum / Double(renderCostFrames) * 1000
        btbDebugLog(String(
            format: "danmaku.render avg=%.2fms max=%.2fms layers=%d",
            average,
            renderCostMax * 1000,
            renderer.layerCount
        ))
        renderCostSum = 0
        renderCostMax = 0
        renderCostFrames = 0
        renderCostLoggedAt = now
    }

    private func logDebugFPSIfNeeded() {
        guard debugFPSEnabled else { return }
        debugFrames += 1
        let now = CACurrentMediaTime()
        let elapsed = now - debugLastLog
        guard elapsed >= 2 else { return }
        let fps = Double(debugFrames) / elapsed
        NSLog("[danmaku] FPS %.0f layers %d", fps, renderer.layerCount)
        debugFPSLabel.text = String(format: "  %.0f fps · %d  ", fps, renderer.layerCount)
        debugFPSLabel.isHidden = false
        debugFrames = 0
        debugLastLog = now
    }
#endif
}
#elseif os(macOS)
private struct DanmakuLayerHost: NSViewRepresentable {
    let player: AVPlayer
    let items: [DanmakuItem]
    let isPlaying: Bool
    let opacity: Double
    let speed: Double
    let fontScale: Double

    func makeNSView(context: Context) -> DanmakuDisplayView {
        let view = DanmakuDisplayView()
        view.apply(player: player, items: items, isPlaying: isPlaying, opacity: opacity, speed: speed, fontScale: fontScale)
        return view
    }

    func updateNSView(_ view: DanmakuDisplayView, context: Context) {
        view.apply(player: player, items: items, isPlaying: isPlaying, opacity: opacity, speed: speed, fontScale: fontScale)
    }

    static func dismantleNSView(_ view: DanmakuDisplayView, coordinator: ()) {
        view.stop()
    }
}

private final class DanmakuDisplayView: NSView {
    private let renderer = DanmakuRenderer()
    private var link: CADisplayLink?
    private var player: AVPlayer?
    private var isPlaying = false
    private var contentsScale: CGFloat = 2

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        renderer.yAxisDown = false
        renderer.contentsScale = contentsScale
        layer?.addSublayer(renderer.container)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        renderer.container.frame = bounds
        CATransaction.commit()
        renderer.render(at: currentPlayerTime, size: bounds.size)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            link?.invalidate()
            link = nil
            return
        }
        contentsScale = window?.backingScaleFactor ?? 2
        renderer.contentsScale = contentsScale
        updateDisplayLink()
        renderer.render(at: currentPlayerTime, size: bounds.size)
    }

    func apply(player: AVPlayer, items: [DanmakuItem], isPlaying: Bool, opacity: Double, speed: Double, fontScale: Double) {
        self.player = player
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            updateDisplayLink()
        }
        renderer.update(items: items, opacity: opacity, speed: speed, fontScale: fontScale)
        if !isPlaying {
            renderer.render(at: currentPlayerTime, size: bounds.size)
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    private var currentPlayerTime: Double {
        guard let seconds = player?.currentTime().seconds, seconds.isFinite else { return 0 }
        return seconds
    }

    private func updateDisplayLink() {
        guard isPlaying, window != nil else {
            link?.isPaused = true
            return
        }
        if link == nil {
            let displayLink = self.displayLink(target: self, selector: #selector(tick(_:)))
            displayLink.add(to: .main, forMode: .common)
            link = displayLink
        }
        link?.isPaused = false
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        guard isPlaying, let player else { return }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite else { return }
        renderer.render(at: seconds, size: bounds.size)
    }
}
#endif

// MARK: - Text textures

/// A comment's text, drawn once into a bitmap and reused for every frame it
/// stays on screen.
///
/// The old renderer used a `CATextLayer` per comment, and each new layer ran
/// CoreText layout and redrew its backing store on the main thread — a burst
/// of comments arriving in the same second stuttered no matter how cheap
/// moving them afterwards was. A layer whose `contents` is a finished CGImage
/// only ever moves, and the textures for the next few seconds are drawn ahead
/// of time on a background queue.
private final class DanmakuTextCache {
    static let shared = DanmakuTextCache()

    private final class Box {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    private let cache = NSCache<NSString, Box>()
    private let queue = DispatchQueue(label: "btb.danmaku.texture", qos: .userInitiated)
    private let lock = NSLock()
    private var queued: Set<String> = []

    private init() {
        cache.countLimit = 900
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    /// Renders now if the texture is not there yet: the first frame of a
    /// comment that was not prewarmed must still show something.
    func image(text: String, color: UInt32, fontSize: CGFloat, pixelScale: CGFloat) -> CGImage? {
        let key = Self.key(text: text, color: color, fontSize: fontSize, pixelScale: pixelScale)
        if let box = cache.object(forKey: key) { return box.image }
        guard let image = Self.draw(text: text, color: color, fontSize: fontSize, pixelScale: pixelScale) else {
            return nil
        }
        cache.setObject(Box(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }

    /// Draws the textures the next few seconds of comments will need.
    func prewarm(_ items: [DanmakuItem], pixelScale: CGFloat) {
        guard !items.isEmpty else { return }
        var payload: [(key: NSString, text: String, color: UInt32, fontSize: CGFloat)] = []
        payload.reserveCapacity(items.count)
        lock.lock()
        for item in items {
            let fontSize = CGFloat(item.fontSize)
            let key = Self.key(text: item.text, color: item.colorValue, fontSize: fontSize, pixelScale: pixelScale)
            guard cache.object(forKey: key) == nil, !queued.contains(key as String) else { continue }
            queued.insert(key as String)
            payload.append((key, item.text, item.colorValue, fontSize))
        }
        lock.unlock()
        guard !payload.isEmpty else { return }

        queue.async { [weak self] in
            guard let self else { return }
            for entry in payload {
                guard let image = Self.draw(
                    text: entry.text,
                    color: entry.color,
                    fontSize: entry.fontSize,
                    pixelScale: pixelScale
                ) else { continue }
                self.cache.setObject(Box(image), forKey: entry.key, cost: image.bytesPerRow * image.height)
            }
            self.lock.lock()
            for entry in payload { self.queued.remove(entry.key as String) }
            self.lock.unlock()
        }
    }

    private static func key(text: String, color: UInt32, fontSize: CGFloat, pixelScale: CGFloat) -> NSString {
        "\(color)|\(Int((fontSize * 10).rounded()))|\(Int((pixelScale * 10).rounded()))|\(text)" as NSString
    }

    private static func draw(text: String, color: UInt32, fontSize: CGFloat, pixelScale: CGFloat) -> CGImage? {
        let size = fontSize * pixelScale
        guard size > 0.5 else { return nil }
        let font = makeFont(size: size)
        // Bilibili comments carry a thin dark outline so white text stays
        // readable over bright frames. CoreText only strokes centred on the
        // glyph path, and the negative width that would keep the outline
        // outside also paints *inside* the glyph: at this texture scale it
        // eats most of every stroke, so the text reads as a hollow white line
        // with a dark twin — the "重影". Draw the stroke first with a positive
        // width, then cover its inner half with the fill.
        let strokeAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTStrokeColorAttributeName as String): CGColor(gray: 0, alpha: 0.9),
            NSAttributedString.Key(kCTStrokeWidthAttributeName as String): 6.0,
        ]
        let fillAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): makeColor(color),
        ]
        let strokeLine = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: strokeAttributes))
        let fillLine = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: fillAttributes))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(fillLine, &ascent, &descent, &leading))
        let pad = max(2, 2 * pixelScale)
        let pixelWidth = Int((width + pad * 2).rounded(.up)) + 1
        let pixelHeight = Int((ascent + descent + pad * 2).rounded(.up)) + 1
        guard pixelWidth > 0, pixelHeight > 0,
              let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.textPosition = CGPoint(x: pad, y: descent + pad)
        CTLineDraw(strokeLine, context)
        context.textPosition = CGPoint(x: pad, y: descent + pad)
        CTLineDraw(fillLine, context)
        return context.makeImage()
    }

    private static func makeFont(size: CGFloat) -> CTFont {
#if os(iOS)
        return UIFont.systemFont(ofSize: size, weight: .semibold) as CTFont
#else
        return NSFont.systemFont(ofSize: size, weight: .semibold) as CTFont
#endif
    }

    private static func makeColor(_ value: UInt32) -> CGColor {
        CGColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

private struct DanmakuLayerRecord {
    let layer: CALayer
    let size: CGSize
}

private final class DanmakuRenderer {
    let container = CALayer()
    var yAxisDown = true
    /// Textures are baked at the screen's pixel scale, so a change of scale
    /// invalidates every layer rather than stretching it.
    var contentsScale: CGFloat = 2 {
        didSet {
            guard contentsScale != oldValue else { return }
            removeAllLayers()
        }
    }

    var layerCount: Int { layers.count }

    private let textures = DanmakuTextCache.shared
    private var items: [DanmakuItem] = []
    private var layers: [String: DanmakuLayerRecord] = [:]
    private var speed: Double = 1
    private var fontScale: Double = 1
    private var lastPrewarm: Double = -.infinity

    init() {
        container.masksToBounds = true
        container.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull(),
            "opacity": NSNull(),
            "contents": NSNull(),
        ]
    }

    func update(items: [DanmakuItem], opacity: Double, speed: Double, fontScale: Double) {
        self.items = items
        self.speed = max(0.25, speed)
        self.fontScale = max(0.1, fontScale)
        container.opacity = Float(min(max(opacity, 0), 1))
    }

    func render(at time: Double, size: CGSize) {
        guard time.isFinite, size.width > 0, size.height > 0 else { return }

        let scale = min(max(size.width / 1280, 0.62), 1.2) * CGFloat(fontScale)
        let lineHeight = 30 * scale
        let scrollLanes = max(1, Int((size.height - 16) / lineHeight))
        let staticLanes = min(3, max(1, Int(size.height * 0.28 / lineHeight)))
        let scrollLifetime = 8.0 / speed
        let maxLifetime = max(4.0, scrollLifetime)
        let pixelScale = scale * contentsScale

        var index = lowerBound(for: time - maxLifetime)
        guard index < items.count else {
            removeAllLayers()
            return
        }

        var active = Set<String>()
        active.reserveCapacity(min(items.count, 64))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        while index < items.count {
            let item = items[index]
            if item.start > time { break }
            index += 1
            guard item.lane >= 0 else { continue }
            let isScroll = item.mode == 1
            let lifetime = isScroll ? scrollLifetime : 4.0
            guard time >= item.start, time <= item.start + lifetime else { continue }
            if isScroll {
                guard item.lane < scrollLanes else { continue }
            } else {
                guard item.lane < staticLanes else { continue }
            }

            active.insert(item.id)
            let record = layerRecord(for: item, pixelScale: pixelScale)
            position(record, item: item, time: time, size: size, lineHeight: lineHeight, scrollLifetime: scrollLifetime)
        }
        CATransaction.commit()

        if active.count != layers.count {
            var stale: [String] = []
            for id in layers.keys where !active.contains(id) {
                stale.append(id)
            }
            for id in stale {
                layers.removeValue(forKey: id)?.layer.removeFromSuperlayer()
            }
        }

        prewarmIfNeeded(at: time, pixelScale: pixelScale)
    }

    /// One layer per comment, carrying a ready texture; creating it never
    /// draws text on the main thread.
    private func layerRecord(for item: DanmakuItem, pixelScale: CGFloat) -> DanmakuLayerRecord {
        if let record = layers[item.id] { return record }

        let layer = CALayer()
        layer.contentsScale = contentsScale
        layer.contentsGravity = .resize
        layer.masksToBounds = false
        // Top-left anchored, so the layer lands on whole device pixels: an
        // odd-height texture centred on a half pixel is resampled every frame
        // and reads as a soft grey twin under the glyphs (the `重影`).
        layer.anchorPoint = .zero
        layer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull(),
            "contents": NSNull(),
            "opacity": NSNull(),
            "hidden": NSNull(),
        ]
        let image = textures.image(
            text: item.text,
            color: item.colorValue,
            fontSize: CGFloat(item.fontSize),
            pixelScale: pixelScale
        )
        var size = CGSize.zero
        if let image {
            layer.contents = image
            size = CGSize(
                width: CGFloat(image.width) / contentsScale,
                height: CGFloat(image.height) / contentsScale
            )
            layer.bounds = CGRect(origin: .zero, size: size)
        }
        container.addSublayer(layer)

        let record = DanmakuLayerRecord(layer: layer, size: size)
        layers[item.id] = record
        return record
    }

    private func position(
        _ record: DanmakuLayerRecord,
        item: DanmakuItem,
        time: Double,
        size: CGSize,
        lineHeight: CGFloat,
        scrollLifetime: Double
    ) {
        let lane = CGFloat(item.lane)
        let top: CGFloat
        switch item.mode {
        case 1, 5:
            top = 8 + lane * lineHeight
        default:
            top = size.height - 14 - (lane + 1) * lineHeight
        }
        // Centre the text in its lane, then place the layer by its top-left
        // corner (anchorPoint `.zero`).
        let textHeight = record.size.height
        let textTop = top + (lineHeight - textHeight) / 2
        let originY = yAxisDown ? textTop : size.height - textTop - textHeight

        if item.mode == 1 {
            let progress = CGFloat((time - item.start) / scrollLifetime)
            // Travel the full picture plus the text itself, so the tail has
            // just left the right edge when the comment expires.
            let travel = record.size.width + 8
            let x = size.width - progress * (size.width + travel)
            record.layer.position = snapped(CGPoint(x: x, y: originY))
        } else {
            let x = (size.width - record.size.width) / 2
            record.layer.position = snapped(CGPoint(x: x, y: originY))
        }
    }

    /// On the device-pixel grid: a texture that lands between two pixels is
    /// resampled on every frame, which reads as a soft, offset twin of the
    /// glyphs underneath the sharp one (`重影`).
    private func snapped(_ point: CGPoint) -> CGPoint {
        let scale = max(contentsScale, 1)
        return CGPoint(
            x: (point.x * scale).rounded() / scale,
            y: (point.y * scale).rounded() / scale
        )
    }

    /// Keeps the next couple of seconds of comments pre-drawn, so the frame a
    /// comment appears in only has to move a layer into place.
    private func prewarmIfNeeded(at time: Double, pixelScale: CGFloat) {
        guard time - lastPrewarm > 0.2, time >= lastPrewarm else { return }
        lastPrewarm = time
        var upcoming: [DanmakuItem] = []
        upcoming.reserveCapacity(64)
        var index = lowerBound(for: time)
        while index < items.count, items[index].start <= time + 2.5, upcoming.count < 64 {
            let item = items[index]
            index += 1
            guard item.lane >= 0 else { continue }
            upcoming.append(item)
        }
        textures.prewarm(upcoming, pixelScale: pixelScale)
    }

    private func removeAllLayers() {
        guard !layers.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for record in layers.values {
            record.layer.removeFromSuperlayer()
        }
        layers.removeAll(keepingCapacity: true)
        CATransaction.commit()
    }

    private func lowerBound(for start: Double) -> Int {
        var low = 0
        var high = items.count
        while low < high {
            let mid = (low + high) / 2
            if items[mid].start < start {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
