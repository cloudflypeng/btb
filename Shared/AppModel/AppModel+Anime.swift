#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func selectAnimeDay(_ date: String) {
        animeSelectedDay = date
    }

    func setAnimeTab(_ tab: AnimeTab) async {
        guard tab != animeTab else { return }
        animeTab = tab
        await loadAnimeFeed(reset: true)
    }

    func loadAnimeFeed(reset: Bool = false) async {
        guard coreState == .ready else { return }
        if reset {
            animeRequest = UUID()
            animeTimeline = []
            animeRankItems = []
            animeRankNote = nil
            animeSelectedDay = nil
            animeLoaded = false
            animeError = nil
            // A reset supersedes any in-flight load; its late response is
            // dropped by the request check and must not keep the spinner up.
            isLoadingAnime = false
        } else {
            guard !animeLoaded else { return }
        }
        guard !isLoadingAnime else { return }

        let request = animeRequest
        isLoadingAnime = true
        animeError = nil
        defer {
            if animeRequest == request {
                isLoadingAnime = false
                animeLoaded = true
            }
        }

        do {
            switch animeTab {
            case .timeline:
                let value = try await core.call("pgc.timeline", params: [
                    "types": .number(1),
                    "before": .number(3),
                    "after": .number(3),
                ])
                let response = try CoreCoding.decode(UpstreamResultResponse<[AnimeTimelineDay]>.self, from: value)
                guard animeRequest == request else { return }
                guard response.code == 0 else {
                    throw BBCoreError.upstream(code: response.code, message: response.message ?? "时间表加载失败")
                }
                animeTimeline = response.result ?? []
                if animeSelectedDay == nil {
                    animeSelectedDay = animeTimeline.first(where: \.isTodayDay)?.date ?? animeTimeline.first?.date
                }
            case .rank:
                let value = try await core.call("pgc.rank", params: [
                    "day": .number(3),
                    "season_type": .number(1),
                ])
                let response = try CoreCoding.decode(UpstreamResultResponse<AnimeRankData>.self, from: value)
                guard animeRequest == request else { return }
                guard response.code == 0 else {
                    throw BBCoreError.upstream(code: response.code, message: response.message ?? "排行榜加载失败")
                }
                animeRankItems = response.result?.list ?? []
            }
        } catch {
            guard animeRequest == request else { return }
            animeError = "番剧加载失败：\(describe(error))"
        }
    }

    func openAnimeSeason(_ seasonID: Int64) {
        guard seasonID > 0, activeAnimeSeasonID != seasonID else { return }
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeArticle()
        closeTopic()
        section = .anime
        activeAnimeSeasonID = seasonID
        animeSeason = nil
        animeSelectedEpisode = nil
        animePlayback = nil
        animeSelectedQN = nil
        animePlayError = nil
        animeSeasonError = nil
        animeReviews = []
        animeReviewCursor = ""
        animeReviewTotal = 0
        animeReviewsLoaded = false
        animeReviewsError = nil
        animeReviewMediaID = nil
        Task { await loadAnimeSeason(seasonID: seasonID) }
    }

    func closeAnimeSeason() {
        let sessionID = animePlayback?.sessionID
        activeAnimeSeasonID = nil
        animeSeason = nil
        animeSelectedEpisode = nil
        animePlayback = nil
        animeSelectedQN = nil
        animePlayError = nil
        animeSeasonError = nil
        animeReviews = []
        animeReviewCursor = ""
        animeReviewTotal = 0
        animeReviewsLoaded = false
        animeReviewsError = nil
        if let sessionID {
            Task { await stopStream(sessionID: sessionID) }
        }
    }

    func loadAnimeSeason(seasonID: Int64, force: Bool = false) async {
        guard activeAnimeSeasonID == seasonID else { return }
        if !force, animeSeason?.seasonID == seasonID { return }
        isLoadingAnimeSeason = true
        animeSeasonError = nil
        defer {
            if activeAnimeSeasonID == seasonID {
                isLoadingAnimeSeason = false
            }
        }

        do {
            let value = try await core.call("pgc.info", params: ["season_id": .number(Double(seasonID))])
            let response = try CoreCoding.decode(UpstreamResultResponse<AnimeSeason>.self, from: value)
            guard activeAnimeSeasonID == seasonID else { return }
            guard response.code == 0, let season = response.result, season.seasonID > 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "番剧信息加载失败")
            }
            animeSeason = season
            if animeSelectedEpisode == nil {
                animeSelectedEpisode = defaultAnimeEpisode(for: season)
            }
            animeReviewMediaID = season.mediaID
            await loadAnimeReviews(reset: true)
#if DEBUG
            if let mode = ProcessInfo.processInfo.environment["BTB_ANIME_PLAY"], !mode.isEmpty, mode != "0" {
                let episode = mode == "newest"
                    ? animeSelectedEpisode
                    : animeSeason?.episodes?.first
                if let episode {
                    await playAnime(episode)
                }
            }
#endif
        } catch {
            guard activeAnimeSeasonID == seasonID else { return }
            animeSeasonError = "番剧信息加载失败：\(describe(error))"
        }
    }

    func defaultAnimeEpisode(for season: AnimeSeason) -> AnimeEpisode? {
        let episodes = season.episodes ?? []
        if let newest = season.newEp?.title,
           let match = episodes.first(where: { $0.title == newest || $0.longTitle == newest }) {
            return match
        }
        return episodes.first
    }

    func playAnime(_ episode: AnimeEpisode, qn: Int? = nil) async {
        guard let seasonID = activeAnimeSeasonID else { return }
        animeSelectedEpisode = episode
        await prepareAnimePlayback(seasonID: seasonID, episode: episode, qn: qn)
    }

    func selectAnimeQuality(_ qn: Int) async {
        guard let episode = animeSelectedEpisode, qn != animeSelectedQN else { return }
        await prepareAnimePlayback(seasonID: activeAnimeSeasonID ?? 0, episode: episode, qn: qn)
    }

    func prepareAnimePlayback(seasonID: Int64, episode: AnimeEpisode, qn: Int?) async {
        guard seasonID > 0, activeAnimeSeasonID == seasonID else { return }
        isLoadingAnimePlay = true
        animePlayError = nil
        defer {
            if activeAnimeSeasonID == seasonID {
                isLoadingAnimePlay = false
            }
        }

        var params: [String: JSONValue] = [
            "season_id": .number(Double(seasonID)),
            "ep_id": .number(Double(episode.epID)),
            "try_look": .bool(true),
        ]
        if let cid = episode.cid, cid > 0 {
            params["cid"] = .number(Double(cid))
        }
        if let qn {
            params["qn"] = .number(Double(qn))
        }

        do {
            let value = try await core.call("pgc.play", params: params)
            let result = try CoreCoding.decode(AnimePlayResult.self, from: value)
            guard activeAnimeSeasonID == seasonID else {
                if let sessionID = result.sessionID {
                    await stopStream(sessionID: sessionID)
                }
                return
            }
            guard result.playable else {
                if qn != nil, animePlayback != nil {
                    showToast(result.unavailableText)
                } else {
                    animePlayback = nil
                    animeSelectedQN = nil
                    animePlayError = result.unavailableText
                }
                return
            }
            let previous = animePlayback?.sessionID
            if let previous, previous != result.sessionID {
                await stopStream(sessionID: previous)
            }
            animePlayback = result
            animeSelectedQN = result.quality?.qn
            if let returned = result.episode, returned.epID > 0 {
                animeSelectedEpisode = returned
            }
        } catch {
            guard activeAnimeSeasonID == seasonID else { return }
            animePlayError = "剧集加载失败：\(describe(error))"
        }
    }

    func toggleAnimeFollow() async {
        guard let season = animeSeason else { return }
        guard hasAccount else {
            presentLogin()
            showToast("请先登录")
            return
        }
        guard !isTogglingAnimeFollow else { return }
        isTogglingAnimeFollow = true
        defer { isTogglingAnimeFollow = false }
        let target = !season.isFollowing
        do {
            _ = try await core.call("pgc.follow", params: [
                "season_id": .number(Double(season.seasonID)),
                "follow": .bool(target),
            ])
            showToast(target ? "已追番" : "已取消追番")
            await loadAnimeSeason(seasonID: season.seasonID, force: true)
        } catch {
            showToast("操作失败：\(describe(error))")
        }
    }

    var animeReviewsHasMore: Bool { !animeReviewCursor.isEmpty }

    func loadAnimeReviews(reset: Bool = false) async {
        guard let mediaID = animeReviewMediaID ?? animeSeason?.mediaID, mediaID > 0 else { return }
        if reset {
            animeReviews = []
            animeReviewCursor = ""
            animeReviewTotal = 0
            animeReviewsLoaded = false
            animeReviewsError = nil
        } else if animeReviewsLoaded, animeReviewsHasMore == false {
            return
        }
        guard !isLoadingAnimeReviews else { return }

        isLoadingAnimeReviews = true
        defer { isLoadingAnimeReviews = false }

        var params: [String: JSONValue] = [
            "media_id": .number(Double(mediaID)),
            "type": .string("short"),
            "ps": .number(12),
            "sort": .number(0),
        ]
        if !animeReviewCursor.isEmpty {
            params["cursor"] = .string(animeReviewCursor)
        }

        do {
            let value = try await core.call("pgc.review", params: params)
            let response = try CoreCoding.decode(UpstreamResponse<AnimeReviewData>.self, from: value)
            guard animeReviewMediaID == mediaID else { return }
            guard response.code == 0 else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "短评加载失败")
            }
            let data = response.data
            let list = data?.list ?? []
            if reset {
                animeReviews = list
            } else {
                animeReviews.append(contentsOf: list)
            }
            animeReviewCursor = data?.next ?? ""
            animeReviewTotal = data?.total ?? animeReviewTotal
            animeReviewsLoaded = true
        } catch {
            guard animeReviewMediaID == mediaID else { return }
            animeReviewsError = "短评加载失败：\(describe(error))"
        }
    }

    func resetAnimeFeed() {
        animeRequest = UUID()
        animeTimeline = []
        animeRankItems = []
        animeSelectedDay = nil
        animeLoaded = false
        animeError = nil
        animeReviewMediaID = nil
        isLoadingAnime = false
    }
}
