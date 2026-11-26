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
        renderer.render(at: seconds, size: bounds.size)
#if DEBUG
        logDebugFPSIfNeeded()
#endif
    }

#if DEBUG
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

private struct DanmakuLayerRecord {
    let layer: CATextLayer
    var fontSize: CGFloat
    var height: CGFloat
    var mode: Int
}

private final class DanmakuRenderer {
    let container = CALayer()
    var yAxisDown = true
    var contentsScale: CGFloat = 2 {
        didSet {
            guard contentsScale != oldValue else { return }
            for record in layers.values {
                record.layer.contentsScale = contentsScale
            }
        }
    }

    var layerCount: Int { layers.count }

    private var items: [DanmakuItem] = []
    private var layers: [String: DanmakuLayerRecord] = [:]
    private var speed: Double = 1
    private var fontScale: Double = 1

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
            let fontSize = CGFloat(item.fontSize) * scale
            let record = layerRecord(for: item, fontSize: fontSize, lineHeight: lineHeight, size: size)
            position(record, item: item, time: time, size: size, lineHeight: lineHeight, scrollLifetime: scrollLifetime, scale: scale)
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
    }

    private func layerRecord(for item: DanmakuItem, fontSize: CGFloat, lineHeight: CGFloat, size: CGSize) -> DanmakuLayerRecord {
        let height = max(lineHeight, fontSize * 1.35)
        if var record = layers[item.id] {
            if abs(record.fontSize - fontSize) > 0.01 || abs(record.height - height) > 0.01 {
                let font = makeFont(size: fontSize)
                record.layer.font = font
                record.layer.fontSize = fontSize
                record.fontSize = fontSize
                record.height = height
                let width = item.mode == 1
                    ? textWidth(item.text, font: font, fontSize: fontSize) + 6
                    : max(size.width, 1)
                record.layer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
                layers[item.id] = record
            }
            return record
        }

        let font = makeFont(size: fontSize)
        let textLayer = CATextLayer()
        textLayer.contentsScale = contentsScale
        textLayer.isWrapped = false
        textLayer.truncationMode = .none
        textLayer.masksToBounds = false
        textLayer.alignmentMode = item.mode == 1 ? .left : .center
        textLayer.anchorPoint = item.mode == 1 ? CGPoint(x: 0, y: 0.5) : CGPoint(x: 0.5, y: 0.5)
        textLayer.font = font
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = makeColor(item.colorValue)
        textLayer.string = item.text
        textLayer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull(),
            "contents": NSNull(),
            "font": NSNull(),
            "fontSize": NSNull(),
            "foregroundColor": NSNull(),
            "string": NSNull(),
            "opacity": NSNull(),
            "hidden": NSNull(),
        ]
        let width = item.mode == 1
            ? textWidth(item.text, font: font, fontSize: fontSize) + 6
            : max(size.width, 1)
        textLayer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        container.addSublayer(textLayer)

        let record = DanmakuLayerRecord(layer: textLayer, fontSize: fontSize, height: height, mode: item.mode)
        layers[item.id] = record
        return record
    }

    private func position(
        _ record: DanmakuLayerRecord,
        item: DanmakuItem,
        time: Double,
        size: CGSize,
        lineHeight: CGFloat,
        scrollLifetime: Double,
        scale: CGFloat
    ) {
        let lane = CGFloat(item.lane)
        let top: CGFloat
        switch item.mode {
        case 1, 5:
            top = 8 + lane * lineHeight
        default:
            top = size.height - 14 - (lane + 1) * lineHeight
        }
        let centerY = top + lineHeight / 2
        let positionY = yAxisDown ? centerY : size.height - centerY

        if item.mode == 1 {
            let progress = CGFloat((time - item.start) / scrollLifetime)
            let travel = CGFloat(item.widthUnits * item.fontSize) * scale + 12
            let x = size.width - progress * (size.width + travel)
            record.layer.position = CGPoint(x: x, y: positionY)
        } else {
            let width = max(size.width, 1)
            if abs(record.layer.bounds.width - width) > 0.5 {
                record.layer.bounds = CGRect(x: 0, y: 0, width: width, height: record.height)
            }
            record.layer.position = CGPoint(x: size.width / 2, y: positionY)
        }
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

    private func makeFont(size: CGFloat) -> CTFont {
#if os(iOS)
        return UIFont.systemFont(ofSize: size, weight: .semibold) as CTFont
#else
        return NSFont.systemFont(ofSize: size, weight: .semibold) as CTFont
#endif
    }

    private func textWidth(_ text: String, font: CTFont, fontSize: CGFloat) -> CGFloat {
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private func makeColor(_ value: UInt32) -> CGColor {
        CGColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
