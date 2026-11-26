#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func downloadJob(for video: VideoItem) -> DownloadJob? {
        downloadJob(bvid: video.bvid, cid: video.cid.map(Int64.init))
    }

    func downloadJob(bvid: String, cid: Int64? = nil) -> DownloadJob? {
        let matches = downloadJobs.filter { $0.bvid == bvid }
        guard !matches.isEmpty else { return nil }
        if let cid {
            let exact = matches.filter { $0.cid == cid }
            if let completed = exact.first(where: { $0.isCompleted }) {
                return completed
            }
            if let first = exact.first {
                return first
            }
        }
        return matches.first(where: { $0.isCompleted }) ?? matches.first
    }

    func loadDownloads(force: Bool = false) async {
        guard coreState == .ready else { return }
        guard force || !downloadLoaded else { return }
        guard !isLoadingDownloads else { return }
        isLoadingDownloads = true
        downloadError = nil
        defer {
            isLoadingDownloads = false
            downloadLoaded = true
        }
        do {
            let value = try await core.call("download.list")
            let result = try CoreCoding.decode(DownloadListResult.self, from: value)
            downloadJobs = sortedDownloads(result.items ?? [])
            downloadUsedBytes = result.usedBytes ?? 0
            downloadFreeBytes = result.freeBytes ?? 0
            downloadDiskBytes = result.diskBytes ?? 0
            if let id = activeDownloadID, !downloadJobs.contains(where: { $0.id == id }) {
                activeDownloadID = nil
            }
        } catch {
            downloadError = "下载列表加载失败：\(describe(error))"
        }
    }

    func applyDownloadConfig() async {
        guard coreState == .ready else { return }
        let defaults = UserDefaults.standard
        let storedConcurrency = defaults.integer(forKey: "download.concurrency")
        let concurrency = storedConcurrency > 0 ? min(max(storedConcurrency, 1), 8) : 1
        let limitKbps = max(0, defaults.integer(forKey: "download.limitKbps"))
        do {
            let value = try await core.call("download.config", params: [
                "concurrency": .number(Double(concurrency)),
                "limit_kbps": .number(Double(limitKbps)),
            ])
            let result = try CoreCoding.decode(DownloadConfigResult.self, from: value)
            if let dir = result.downloadDir, !dir.isEmpty {
                downloadDirectory = dir
            }
        } catch {
            downloadDirectory = ""
        }
    }

    func startDownload(
        for video: VideoItem,
        detail: VideoInfoData?,
        qn: Int64? = nil,
        codec: String? = nil
    ) async {
        if let existing = downloadJob(for: video), !existing.isFailed {
            showToast(existing.isCompleted ? "该视频已下载" : "该视频已在下载列表中")
            return
        }
        let defaults = UserDefaults.standard
        let defaultQN = defaults.integer(forKey: "download.defaultQN")
        let resolvedQN = qn ?? Int64(defaultQN > 0 ? defaultQN : 80)
        let resolvedCodec = codec ?? defaults.string(forKey: "download.defaultCodec") ?? "hevc"
        let cid = detail?.cid.map(Int64.init) ?? video.cid.map(Int64.init)
        let seconds = Int64(detail?.duration ?? 0)
        await startDownload(
            bvid: video.bvid,
            cid: cid,
            title: detail?.title ?? video.title,
            cover: detail?.pic ?? video.coverURL?.absoluteString,
            owner: detail?.owner?.name ?? video.ownerName,
            durationMS: seconds > 0 ? seconds * 1000 : nil,
            qn: resolvedQN,
            codec: resolvedCodec
        )
    }

    func startDownload(
        bvid: String,
        cid: Int64?,
        title: String,
        cover: String?,
        owner: String?,
        durationMS: Int64?,
        qn: Int64 = 80,
        codec: String = "hevc"
    ) async {
        guard coreState == .ready else { return }
        if let existing = downloadJob(bvid: bvid), !existing.isFailed {
            showToast(existing.isCompleted ? "该视频已下载" : "该视频已在下载列表中")
            return
        }
        var params: [String: JSONValue] = [
            "bvid": .string(bvid),
            "qn": .number(Double(qn)),
            "codec": .string(codec),
            "title": .string(title),
        ]
        if let cid, cid > 0 {
            params["cid"] = .number(Double(cid))
        }
        if let cover, !cover.isEmpty {
            params["cover"] = .string(cover)
        }
        if let owner, !owner.isEmpty {
            params["owner"] = .string(owner)
        }
        if let durationMS, durationMS > 0 {
            params["duration_ms"] = .number(Double(durationMS))
        }
        do {
            let value = try await core.call("download.start", params: params)
            upsertDownload(try CoreCoding.decode(DownloadJob.self, from: value))
            showToast("已开始下载")
        } catch {
            showToast("下载失败：\(describe(error))")
        }
    }

    func pauseDownload(_ job: DownloadJob) async {
        guard job.isDownloading, !downloadActionIDs.contains(job.id) else { return }
        downloadActionIDs.insert(job.id)
        defer { downloadActionIDs.remove(job.id) }
        do {
            let value = try await core.call("download.pause", params: ["id": .string(job.id)])
            upsertDownload(try CoreCoding.decode(DownloadJob.self, from: value))
            showToast("已暂停下载")
            await loadDownloads(force: true)
        } catch {
            showToast("暂停失败：\(describe(error))")
        }
    }

    func resumeDownload(_ job: DownloadJob) async {
        guard job.isPaused || job.isFailed, !downloadActionIDs.contains(job.id) else { return }
        downloadActionIDs.insert(job.id)
        defer { downloadActionIDs.remove(job.id) }
        do {
            let value = try await core.call("download.resume", params: ["id": .string(job.id)])
            upsertDownload(try CoreCoding.decode(DownloadJob.self, from: value))
            showToast("继续下载")
            await loadDownloads(force: true)
        } catch {
            showToast("继续下载失败：\(describe(error))")
        }
    }

    func removeDownload(_ job: DownloadJob) async {
        guard !downloadActionIDs.contains(job.id) else { return }
        downloadActionIDs.insert(job.id)
        defer { downloadActionIDs.remove(job.id) }
        do {
            _ = try await core.call("download.remove", params: ["id": .string(job.id)])
            downloadJobs.removeAll { $0.id == job.id }
            if activeDownloadID == job.id {
                activeDownloadID = nil
            }
            downloadUsedBytes = downloadJobs.reduce(0) { $0 + $1.downloadedBytes }
            showToast("已删除下载")
            await loadDownloads(force: true)
        } catch {
            showToast("删除失败：\(describe(error))")
        }
    }

    func downloadPlaybackURL(for job: DownloadJob) async -> URL? {
        if let raw = job.masterURL, let url = URL(string: raw) {
            return url
        }
        guard job.isCompleted else { return nil }
        do {
            let value = try await core.call("download.url", params: ["id": .string(job.id)])
            let result = try CoreCoding.decode(DownloadURLResult.self, from: value)
            return URL(string: result.masterURL)
        } catch {
            showToast("无法播放该下载：\(describe(error))")
            return nil
        }
    }

    func openDownload(_ job: DownloadJob) {
        guard job.isCompleted else { return }
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        closeTopic()
        activeDownloadID = job.id
        section = .downloads
    }

    func closeDownload() {
        activeDownloadID = nil
    }

    func sortedDownloads(_ jobs: [DownloadJob]) -> [DownloadJob] {
        jobs.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id > rhs.id
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    func startDownloadEventStream() {
        downloadEventsTask?.cancel()
        let stream = eventHub.subscribe(topics: ["download.*"])
        downloadEventsTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard !Task.isCancelled else { return }
                self?.handleDownloadEvent(event)
            }
        }
    }

    func handleDownloadEvent(_ event: CoreEvent) {
        guard let job = try? CoreCoding.decode(DownloadJob.self, from: event.data) else { return }
        upsertDownload(job)
        switch event.topic {
        case "download.completed":
            showToast("下载完成：\(job.title)")
        case "download.failed":
            showToast("下载失败：\(job.title)")
        default:
            break
        }
    }

    func upsertDownload(_ job: DownloadJob) {
        if let index = downloadJobs.firstIndex(where: { $0.id == job.id }) {
            downloadJobs[index] = job
        } else {
            downloadJobs.append(job)
        }
        downloadJobs = sortedDownloads(downloadJobs)
        downloadUsedBytes = downloadJobs.reduce(0) { $0 + $1.downloadedBytes }
    }
}
