import Foundation

/// Keeps each home tab's feed alive across tab switches (#2).
///
/// Without this, switching to 热门 and back re-fetches 推荐 and lands at the top
/// of a brand-new list. With it, a tab comes back to exactly the content it
/// showed, and the list restores its scroll anchor by video id.
extension AppModel {
    /// Feed state for one (tab, filter) pair.
    struct HomeSnapshot {
        var videos: [VideoItem]
        var isLoading: Bool
        var nextPage: Int
        var hasMore: Bool
    }

    var homeSnapshotKey: String {
        "\(homeTab.rawValue)|\(homeFilter.rawValue)"
    }

    func saveHomeSnapshot() {
        guard !videos.isEmpty else {
#if DEBUG
            btbDebugLog("snapshot.save.skip key=\(homeSnapshotKey) empty")
#endif
            return
        }
#if DEBUG
        btbDebugLog("snapshot.save key=\(homeSnapshotKey) count=\(videos.count) first=\(videos.first?.title ?? "-")")
#endif
        homeSnapshots[homeSnapshotKey] = HomeSnapshot(
            videos: videos,
            isLoading: false,
            nextPage: homePager.nextPage,
            hasMore: homePager.hasMore
        )
        // Ten tabs is already far more than the four in the bar.
        if homeSnapshots.count > 10 {
            homeSnapshots.removeValue(forKey: homeSnapshotKey)
        }
    }

    /// Restores a tab's feed if it was seen before. Returns `false` when the
    /// caller should load from the network instead.
    @discardableResult
    func restoreHomeSnapshot(for key: String) -> Bool {
        guard let snapshot = homeSnapshots[key], !snapshot.videos.isEmpty else {
#if DEBUG
            btbDebugLog("snapshot.restore.miss key=\(key) known=\(homeSnapshots.keys.sorted().joined(separator: ","))")
#endif
            return false
        }
#if DEBUG
        btbDebugLog("snapshot.restore key=\(key) count=\(snapshot.videos.count) first=\(snapshot.videos.first?.title ?? "-")")
#endif
        videos = snapshot.videos
        isLoading = false
        errorMessage = nil
        homePager.reset()
        homePager.nextPage = snapshot.nextPage
        homePager.hasMore = snapshot.hasMore
        return true
    }

    /// Drops a tab's cached feed so the next visit fetches fresh content.
    func dropHomeSnapshot(_ key: String) {
        homeSnapshots.removeValue(forKey: key)
    }
}
