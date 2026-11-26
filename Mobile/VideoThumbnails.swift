import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// D2: scrub-bar preview frames, cut out of Bilibili's `videoshot` sprite.
///
/// The endpoint hands back a handful of sprite sheets, each a grid of
/// `img_x_len × img_y_len` frames. `index` is the timestamp (in seconds) of
/// every frame, in sheet order — the frame number is the array position, not
/// the value (a 20-minute video's `index` ends at ~1200). One sheet is fetched
/// up front and the rest only when a scrub reaches them, so a long video costs
/// nothing until it is actually dragged through.
@MainActor
@Observable
final class VideoThumbnails {
    private(set) var isLoading = false
    private(set) var hasFrames = false

    private var bvid = ""
    private var cid: Int64 = 0
    private var duration: Double = 0

    private var sheetURLs: [URL] = []
    /// Seconds at which each sprite frame was taken, in frame order.
    private var frameTimes: [Int] = []
    private var frameCount = 0
    private var perSheet = 0
    private var cellSize = CGSize.zero

    private var sheets: [Int: CGImage] = [:]
    private var inFlight: Set<Int> = []
    /// Bumped whenever a sheet lands, so a preview already on screen redraws
    /// with the frame it was waiting for.
    private var revision = 0

    /// Loads the sheet index and the first sheet, then keeps the rest lazy.
    func prepare(core: any CoreTransport, bvid: String, cid: Int64?, duration: Double) async {
        guard !bvid.isEmpty, let cid, cid > 0, duration > 0 else { return }
        guard bvid != self.bvid || cid != self.cid else { return }
        self.bvid = bvid
        self.cid = cid
        self.duration = duration
        sheets.removeAll()
        frameTimes.removeAll()
        sheetURLs.removeAll()
        hasFrames = false
        isLoading = true
        defer { isLoading = false }

        let value: JSONValue
        do {
            value = try await core.call("player.videoshot", params: [
                "bvid": .string(bvid),
                "cid": .number(Double(cid)),
            ])
        } catch {
            btbDebugLog("videoshot.miss bvid=\(bvid) \(error.localizedDescription)")
            return
        }
        let root = value.objectValue
        let data = (root?["data"]?.objectValue) ?? root
        guard let data,
              let images = data["image"]?.arrayValue,
              !images.isEmpty
        else { return }

        let xLen = data["img_x_len"]?.intValue ?? 10
        let yLen = data["img_y_len"]?.intValue ?? 10
        let xSize = data["img_x_size"]?.intValue ?? 160
        let ySize = data["img_y_size"]?.intValue ?? 90
        guard xLen > 0, yLen > 0 else { return }

        sheetURLs = images.compactMap { raw in
            guard var text = raw.stringValue else { return nil }
            if text.hasPrefix("//") { text = "https:" + text }
            if text.hasPrefix("http://") { text = "https://" + text.dropFirst(7) }
            return URL(string: text)
        }
        frameTimes = (data["index"]?.arrayValue ?? []).compactMap { $0.intValue }
        perSheet = xLen * yLen
        cellSize = CGSize(width: xSize, height: ySize)
        // The newer pvdata snapshots ship an empty `index`; the frames are
        // still one per cell, taken evenly across the video, so lay them all
        // out on the timeline instead.
        frameCount = frameTimes.isEmpty
            ? sheetURLs.count * perSheet
            : frameTimes.count
        hasFrames = !sheetURLs.isEmpty && frameCount > 0
        await loadSheet(0)
    }

    /// The frame for a playback position, once its sheet is around.
    func image(at time: Double) -> CGImage? {
        guard hasFrames, duration > 0, perSheet > 0, frameCount > 0 else { return nil }
        _ = revision
        let sample = frame(at: time)
        let sheetIndex = sample / perSheet
        guard sheetIndex >= 0, sheetIndex < sheetURLs.count else { return nil }
        guard let sheet = sheets[sheetIndex] else {
            Task { await loadSheet(sheetIndex) }
            return nil
        }
        let slot = sample % perSheet
        let columns = max(Int((CGFloat(sheet.width) / max(cellSize.width, 1)).rounded(.down)), 1)
        let column = slot % columns
        let row = slot / columns
        let rect = CGRect(
            x: CGFloat(column) * cellSize.width,
            y: CGFloat(row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )
        return sheet.cropping(to: rect)
    }

    /// The sprite frame covering `time`: an exact lookup through the timestamp
    /// table when there is one, an even spread over the frames otherwise.
    private func frame(at time: Double) -> Int {
        guard !frameTimes.isEmpty else {
            let ratio = min(max(time / duration, 0), 1)
            return min(Int((ratio * Double(frameCount - 1)).rounded()), frameCount - 1)
        }
        // Last frame whose timestamp has already passed.
        var low = 0
        var high = frameTimes.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if Double(frameTimes[mid]) <= time {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    private func loadSheet(_ index: Int) async {
        guard index >= 0, index < sheetURLs.count else { return }
        guard sheets[index] == nil, !inFlight.contains(index) else { return }
        inFlight.insert(index)
        defer { inFlight.remove(index) }
        guard let image = await BtbImagePipeline.fetch(
            sheetURLs[index],
            cacheKey: "videoshot:\(sheetURLs[index].absoluteString)",
            pixels: 0
        ) else {
            return
        }
        #if canImport(UIKit)
        guard let cg = image.cgImage else { return }
        #else
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        #endif
        sheets[index] = cg
        revision &+= 1
    }
}
