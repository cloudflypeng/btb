import AVFoundation
import Foundation
import Photos
import UIKit

/// A finished download is two fragmented MP4 tracks plus playlists in the
/// core's sandbox. The photo library wants one playable movie, so the tracks
/// are stitched with a passthrough export — no re-encode, no quality loss —
/// and the result is handed to Photos as a single video resource.
@MainActor
enum MobilePhotoLibrary {
    static let albumName = "BTB"

    enum SaveError: LocalizedError {
        case notCompleted
        case filesMissing
        case notAuthorized
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .notCompleted: "下载还没有完成"
            case .filesMissing: "找不到下载的文件"
            case .notAuthorized: "没有相册权限，请到「设置 · BTB · 照片」里允许添加"
            case .exportFailed(let reason): reason.isEmpty ? "视频导出失败" : "视频导出失败：\(reason)"
            }
        }
    }

    static func save(job: DownloadJob, downloadDirectory: String) async throws {
        guard job.isCompleted else { throw SaveError.notCompleted }
        guard !downloadDirectory.isEmpty else { throw SaveError.filesMissing }

        let dir = URL(fileURLWithPath: downloadDirectory, isDirectory: true)
            .appendingPathComponent(job.id, isDirectory: true)
        let videoURL = dir.appendingPathComponent("video.mp4")
        guard FileManager.default.fileExists(atPath: videoURL.path) else { throw SaveError.filesMissing }
        let audioURL = dir.appendingPathComponent("audio.mp4")
        let audio = FileManager.default.fileExists(atPath: audioURL.path) ? audioURL : nil

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.notAuthorized }

        let movie = try await stitch(video: videoURL, audio: audio)
        defer { try? FileManager.default.removeItem(at: movie) }
        try await addToLibrary(movie)
    }

    // MARK: - Stitching

    private static func stitch(video: URL, audio: URL?) async throws -> URL {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let videoDuration = try await videoAsset.load(.duration)
        if let track = try await videoAsset.loadTracks(withMediaType: .video).first,
           let target = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try target.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoDuration),
                of: track,
                at: .zero
            )
            target.preferredTransform = try await track.load(.preferredTransform)
        }

        if let audio {
            let audioAsset = AVURLAsset(url: audio)
            let audioDuration = try await audioAsset.load(.duration)
            if let track = try await audioAsset.loadTracks(withMediaType: .audio).first,
               let target = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                try target.insertTimeRange(
                    CMTimeRange(start: .zero, duration: audioDuration),
                    of: track,
                    at: .zero
                )
            }
        }

        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw SaveError.exportFailed("")
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("btb-photo-\(UUID().uuidString).mp4")
        export.outputURL = output
        export.outputFileType = .mp4

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously { continuation.resume() }
        }
        switch export.status {
        case .completed:
            return output
        default:
            let message = export.error?.localizedDescription
                ?? (export.status == .cancelled ? "已取消" : "")
            throw SaveError.exportFailed(message)
        }
    }

    // MARK: - Photos

    private static func addToLibrary(_ fileURL: URL) async throws {
        var placeholderID: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = Date()
            request.addResource(with: .video, fileURL: fileURL, options: nil)
            placeholderID = request.placeholderForCreatedAsset?.localIdentifier
        }
        guard let placeholderID else { return }

        // The asset is already in the library (Recents); the album is only a
        // second way to find it, so a failure here does not undo the save.
        guard let album = try? await album(named: albumName) else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [placeholderID], options: nil)
            PHAssetCollectionChangeRequest(for: album)?.addAssets(assets)
        }
    }

    private static func album(named name: String) async throws -> PHAssetCollection {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        let existing = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: options
        )
        if let album = existing.firstObject { return album }

        var localID: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            localID = request.placeholderForCreatedAssetCollection.localIdentifier
        }
        guard let localID,
              let created = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [localID],
                options: nil
              ).firstObject
        else { throw SaveError.exportFailed("无法创建「\(name)」相册") }
        return created
    }
}
