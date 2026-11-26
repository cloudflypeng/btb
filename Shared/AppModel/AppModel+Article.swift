#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

extension AppModel {
    func openArticle(id: Int64) {
        guard id > 0 else { return }
        closeVideo()
        closeUP()
        closeDynamic()
        closeLiveRoom()
        closeAnimeSeason()
        closeTopic()
        activeArticleID = id
        articleDetail = nil
        articleError = nil
        isLoadingArticle = false
        Task { await loadArticle(id: id) }
    }

    func closeArticle() {
        activeArticleID = nil
        articleDetail = nil
        articleError = nil
        isLoadingArticle = false
    }

    func loadArticle(id: Int64? = nil, force: Bool = false) async {
        guard let target = id ?? activeArticleID else { return }
        guard coreState == .ready else { return }
        if !force, articleDetail?.id == target { return }
        guard !isLoadingArticle else { return }

        isLoadingArticle = true
        articleError = nil
        defer {
            if activeArticleID == target { isLoadingArticle = false }
        }
        do {
            let value = try await core.call("article.view", params: [
                "article_id": .integer(target),
            ])
            let response = try CoreCoding.decode(ArticleDetailResponse.self, from: value)
            guard response.code == 0, let detail = response.data else {
                throw BBCoreError.upstream(code: response.code, message: response.message ?? "专栏加载失败")
            }
            guard activeArticleID == target else { return }
            articleDetail = detail
        } catch {
            guard activeArticleID == target else { return }
            articleError = "专栏加载失败：\(describe(error))"
        }
    }
}
