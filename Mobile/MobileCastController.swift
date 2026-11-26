import Foundation
import Observation

/// Casting to a TV, the same way the Android app does it: the Go core runs the
/// SSDP search and the DLNA session, so any renderer — 云视听小电视 included —
/// shows up here, which AirPlay alone never could.
@MainActor
@Observable
final class MobileCastController {
    struct Target: Equatable {
        let device: CastDeviceInfo
        let title: String
        let mode: String?

        /// The TV fetches the stream itself, so the phone may leave.
        var isDirect: Bool { mode == "direct" }
    }

    private(set) var devices: [CastDeviceInfo] = []
    private(set) var isDiscovering = false
    private(set) var isBusy = false
    private(set) var target: Target?
    private(set) var error: String?

    private var core: (any CoreTransport)?

    var hasTarget: Bool { target != nil }

    func attach(core: any CoreTransport) {
        self.core = core
    }

    /// Searches the local network. SSDP needs a couple of seconds, so this is
    /// called when the sheet opens rather than up front.
    func discover(timeoutMS: Int = 3000) async {
        guard let core, !isDiscovering, !isBusy else { return }
        isDiscovering = true
        error = nil
        defer { isDiscovering = false }
        do {
            let value = try await core.call(
                "cast.discover",
                params: ["timeout_ms": .number(Double(timeoutMS))]
            )
            let response = try CoreCoding.decode(CastDevicesResponse.self, from: value)
            devices = response.devices
            if devices.isEmpty {
                error = nil
            }
        } catch {
            self.error = Self.message(error, fallback: "搜索附近设备失败")
        }
    }

    func cast(to device: CastDeviceInfo, video: VideoItem, playback: MobilePlaybackController) async {
        guard let core, !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }

        let resolved = playback.resolved
        let title = playback.video?.title ?? video.title
        var params: [String: JSONValue] = [
            "control_url": .string(device.avTransportURL),
            "title": .string(title),
            "page": .number(Double(resolved?.page ?? 1)),
        ]
        let bvid = resolved?.bvid ?? video.bvid
        if !bvid.isEmpty { params["bvid"] = .string(bvid) }
        if let cid = resolved?.cid ?? video.cid.map(Int64.init), cid > 0 {
            params["cid"] = .number(Double(cid))
        }
        if let qn = playback.selectedQuality?.qn ?? resolved?.defaultQN, qn > 0 {
            params["qn"] = .number(Double(qn))
        }
        if let codec = playback.selectedQuality?.codec ?? resolved?.defaultCodec, !codec.isEmpty {
            params["codec"] = .string(codec)
        }
        let positionMS = Int64(playback.currentTime * 1000)
        if positionMS > 1000 {
            params["position_ms"] = .number(Double(positionMS))
        }

        do {
            let value = try await core.call("cast.play", params: params)
            let result = try CoreCoding.decode(CastPlayResult.self, from: value)
            guard result.playing else {
                let message = result.message?.trimmingCharacters(in: .whitespaces) ?? ""
                self.error = message.isEmpty ? "投屏失败" : message
                return
            }
            let active = result.device ?? device
            target = Target(
                device: active,
                title: result.title.flatMap { $0.isEmpty ? nil : $0 } ?? title,
                mode: result.mode
            )
            // The phone stops rendering; the TV owns the picture from here.
            if playback.isPlaying { playback.togglePlayback() }
            playback.setCasting(true, deviceName: active.name)
        } catch {
            self.error = Self.message(error, fallback: "投屏失败")
        }
    }

    func stop(playback: MobilePlaybackController? = nil) async {
        guard let core else { return }
        isBusy = true
        defer { isBusy = false }
        _ = try? await core.call("cast.stop")
        target = nil
        playback?.setCasting(false, deviceName: nil)
    }

    func clearError() {
        error = nil
    }

    private static func message(_ error: Error, fallback: String) -> String {
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? fallback : trimmed).prefix(160))
    }
}
