#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func loadPlaylists(force: Bool = false) async {
        guard hasAccount else {
            favoriteFolders = []
            playlistsError = nil
            return
        }
        guard force || favoriteFolders.isEmpty, !isLoadingPlaylists else { return }
        isLoadingPlaylists = true
        playlistsError = nil
        defer { isLoadingPlaylists = false }

        do {
            let value = try await core.call("fav.folders")
            let response = try CoreCoding.decode(UpstreamResponse<FavFoldersData>.self, from: value)
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "播放列表加载失败")
            }
            favoriteFolders = (response.data?.list ?? []).compactMap { FavFolder(raw: $0) }
            if let selected = selectedFolder,
               let refreshed = favoriteFolders.first(where: { $0.id == selected.id }) {
                selectedFolder = refreshed
            }
        } catch {
            playlistsError = "播放列表加载失败：\(describe(error))"
        }
    }

    func createFavoriteFolder(
        title: String,
        intro: String,
        privacy: Int,
        cover: String
    ) async throws -> FavFolder? {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.create_folder", params: [
            "title": .string(title),
            "intro": .string(intro),
            "privacy": .number(Double(privacy)),
            "cover": .string(cover),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FavFolderRaw>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "创建收藏夹失败")
        }
        guard let folder = response.data.flatMap({ FavFolder(raw: $0) }) else {
            await loadPlaylists(force: true)
            showToast("收藏夹已创建")
            return nil
        }
        favoriteFolders.append(folder)
        showToast("收藏夹已创建")
        return folder
    }

    func updateFavoriteFolder(
        _ folder: FavFolder,
        title: String,
        intro: String,
        privacy: Int,
        cover: String
    ) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.edit_folder", params: [
            "media_id": .number(Double(folder.id)),
            "title": .string(title),
            "intro": .string(intro),
            "privacy": .number(Double(privacy)),
            "cover": .string(cover),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FavFolderRaw>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "保存收藏夹失败")
        }
        if let raw = response.data, let updated = FavFolder(raw: raw) {
            replaceFolder(updated)
        } else {
            var updated = folder
            updated.title = title
            updated.intro = intro
            updated.isPrivate = privacy == 1
            replaceFolder(updated)
        }
        showToast("收藏夹已更新")
    }

    func deleteFavoriteFolder(_ folder: FavFolder) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.delete_folder", params: [
            "media_ids": .string(String(folder.id)),
        ])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "删除收藏夹失败")
        }
        favoriteFolders.removeAll { $0.id == folder.id }
        if selectedFolder?.id == folder.id {
            closeFolder()
        }
        showToast("收藏夹已删除")
    }

    func cleanFavoriteFolder(_ folder: FavFolder) async throws {
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.clean", params: [
            "media_id": .number(Double(folder.id)),
        ])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "清空收藏夹失败")
        }
        adjustFolderCount(folder.id, delta: -folder.count)
        if selectedFolder?.id == folder.id {
            folderVideos = []
            folderPager.stop()
        }
        showToast("收藏夹已清空")
    }

    func removeFavoriteVideos(_ videos: [VideoItem], from folder: FavFolder) async throws {
        let resources = favoriteResources(for: videos)
        guard !resources.isEmpty else {
            throw BBCoreError.upstream(code: -1, message: "无法识别所选视频")
        }
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let value = try await core.call("fav.remove", params: [
            "media_id": .number(Double(folder.id)),
            "resources": .string(resources.joined(separator: ",")),
        ])
        let response = try CoreCoding.decode(BasicResponse.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "取消收藏失败")
        }
        let removed = Set(videos.map(\.bvid))
        if selectedFolder?.id == folder.id {
            folderVideos.removeAll { removed.contains($0.bvid) }
        }
        adjustFolderCount(folder.id, delta: -videos.count)
        showToast("已取消收藏 \(videos.count) 个视频")
    }

    func moveFavoriteVideos(
        _ videos: [VideoItem],
        from folder: FavFolder,
        to target: FavFolder
    ) async throws {
        let resources = favoriteResources(for: videos)
        guard !resources.isEmpty else {
            throw BBCoreError.upstream(code: -1, message: "无法识别所选视频")
        }
        guard hasAccount else {
            throw BBCoreError.upstream(code: -1, message: "请先登录")
        }
        let joined = resources.joined(separator: ",")

        let addValue = try await core.call("fav.add", params: [
            "resources": .string(joined),
            "add_media_ids": .string(String(target.id)),
        ])
        let addResponse = try CoreCoding.decode(BasicResponse.self, from: addValue)
        guard addResponse.code == 0 else {
            throw BBCoreError.upstream(code: addResponse.code, message: addResponse.message ?? "移动到目标收藏夹失败")
        }

        let removeValue = try await core.call("fav.remove", params: [
            "media_id": .number(Double(folder.id)),
            "resources": .string(joined),
        ])
        let removeResponse = try CoreCoding.decode(BasicResponse.self, from: removeValue)
        guard removeResponse.code == 0 else {
            throw BBCoreError.upstream(
                code: removeResponse.code,
                message: "视频已加入目标收藏夹，但移出原收藏夹失败"
            )
        }

        let moved = Set(videos.map(\.bvid))
        if selectedFolder?.id == folder.id {
            folderVideos.removeAll { moved.contains($0.bvid) }
        }
        adjustFolderCount(folder.id, delta: -videos.count)
        adjustFolderCount(target.id, delta: videos.count)
        showToast("已移动 \(videos.count) 个视频")
    }

    func favoriteResources(for videos: [VideoItem]) -> [String] {
        videos.compactMap { video in
            guard let aid = video.aid, aid > 0 else { return nil }
            return "\(aid):2"
        }
    }

    func replaceFolder(_ folder: FavFolder) {
        if let index = favoriteFolders.firstIndex(where: { $0.id == folder.id }) {
            favoriteFolders[index] = folder
        }
        if selectedFolder?.id == folder.id {
            selectedFolder = folder
        }
    }

    func adjustFolderCount(_ mediaID: Int64, delta: Int) {
        guard delta != 0 else { return }
        if let index = favoriteFolders.firstIndex(where: { $0.id == mediaID }) {
            favoriteFolders[index].count = max(0, favoriteFolders[index].count + delta)
        }
        if let selected = selectedFolder, selected.id == mediaID {
            selectedFolder?.count = max(0, selected.count + delta)
        }
    }

    func loadFolderVideos(_ folder: FavFolder) async {
        guard hasAccount else { return }
        if selectedFolder?.id != folder.id {
            selectedFolder = folder
            folderVideos = []
            folderPager.reset()
        }
        guard !isLoadingFolderVideos else { return }
        isLoadingFolderVideos = true
        folderError = nil
        folderPager.reset()
        defer { isLoadingFolderVideos = false }

        do {
            let page = try await fetchFolderPage(folder.id, page: 1)
            guard selectedFolder?.id == folder.id else { return }
            folderVideos = page.items
            if let info = page.info {
                replaceFolder(info)
            }
            folderPager.nextPage = 2
            folderPager.hasMore = folderHasMore(
                page: page,
                loadedCount: folderVideos.count,
                total: page.info?.count ?? folder.count
            )
        } catch {
            guard selectedFolder?.id == folder.id else { return }
            folderError = "播放列表加载失败：\(describe(error))"
            folderPager.hasMore = false
        }
    }

    func loadMoreFolderVideos() async {
        guard let folder = selectedFolder,
              !isLoadingFolderVideos,
              !folderPager.isLoadingMore,
              folderPager.hasMore else { return }
        folderPager.isLoadingMore = true
        folderPager.failed = false
        defer {
            if selectedFolder?.id == folder.id { folderPager.isLoadingMore = false }
        }

        let page = folderPager.nextPage
        do {
            let result = try await fetchFolderPage(folder.id, page: page)
            guard selectedFolder?.id == folder.id else { return }
            folderPager.nextPage = page + 1
            if result.items.isEmpty {
                folderPager.stop()
                return
            }
            _ = appendUnique(result.items, to: &folderVideos)
            folderPager.hasMore = folderHasMore(
                page: result,
                loadedCount: folderVideos.count,
                total: selectedFolder?.count ?? folder.count
            )
        } catch {
            guard selectedFolder?.id == folder.id else { return }
            folderPager.failed = true
        }
    }

    func fetchFolderPage(
        _ mediaID: Int64,
        page: Int
    ) async throws -> (items: [VideoItem], hasMore: Bool?, info: FavFolder?) {
        let value = try await core.call("fav.list", params: [
            "media_id": .number(Double(mediaID)),
            "pn": .number(Double(page)),
            "ps": .number(Double(libraryPageSize)),
        ])
        let response = try CoreCoding.decode(UpstreamResponse<FavListData>.self, from: value)
        guard response.code == 0 else {
            throw BBCoreError.upstream(code: response.code, message: response.message ?? "播放列表加载失败")
        }
        let items = (response.data?.medias ?? []).compactMap(VideoItem.init(fav:))
        let info = response.data?.info.flatMap { FavFolder(raw: $0) }
        return (items, response.data?.hasMore, info)
    }

    func folderHasMore(
        page: (items: [VideoItem], hasMore: Bool?, info: FavFolder?),
        loadedCount: Int,
        total: Int
    ) -> Bool {
        if let hasMore = page.hasMore { return hasMore }
        if total > 0 { return loadedCount < total }
        return page.items.count >= libraryPageSize
    }

    func closeFolder() {
        selectedFolder = nil
        folderVideos = []
        folderError = nil
        isLoadingFolderVideos = false
        folderPager.reset()
    }
}
