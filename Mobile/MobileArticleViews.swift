import SwiftUI
import UIKit
import WebKit

struct MobileArticleRoute: Hashable, Identifiable {
    let articleID: Int64

    var id: Int64 { articleID }
}

struct MobileArticleRankView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selected: MobileArticleRoute?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            content
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $selected) { route in
            MobileArticleView(articleID: route.articleID)
        }
        .task {
            await model.loadArticleRank()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("专栏")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            if !model.articleRank.isEmpty {
                Text("\(model.articleRank.count) 篇")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            Spacer()
            Button {
                Task { await model.loadArticleRank(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingArticleRank)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if let error = model.articleRankError {
                    MobileErrorBanner(text: error) {
                        Task { await model.loadArticleRank(force: true) }
                    }
                    .padding(.bottom, 6)
                }

                if model.isLoadingArticleRank && model.articleRank.isEmpty {
                    ProgressView()
                        .tint(AppTheme.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if model.articleRank.isEmpty {
                    if model.articleRankError == nil {
                        MobileEmptyState(
                            icon: "doc.text",
                            title: "暂无专栏",
                            message: "稍后刷新试试"
                        )
                    }
                } else {
                    ForEach(Array(model.articleRank.enumerated()), id: \.element.id) { index, article in
                        Button {
                            selected = MobileArticleRoute(articleID: article.id)
                        } label: {
                            MobileArticleRankRow(article: article, rank: index + 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.loadArticleRank(force: true)
        }
    }
}

private struct MobileArticleRankRow: View {
    let article: ArticleRankItem
    let rank: Int

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? AppTheme.brand : AppTheme.tertiary(scheme))
                .frame(width: 24, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !article.summaryText.isEmpty {
                    Text(article.summaryText)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 5) {
                    Text(articleMeta)
                        .lineLimit(1)
                }
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.tertiary(scheme))
            }

            Spacer(minLength: 6)

            if let cover = article.coverURL {
                RemoteImage(url: cover)
                    .frame(width: 106, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var articleMeta: String {
        [article.authorName, article.publishedText, article.statsText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct MobileArticleView: View {
    let articleID: Int64

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let detail = model.articleDetail, detail.id == articleID {
                MobileArticleWebView(
                    html: ArticleHTMLBuilder.html(for: detail, scheme: scheme, compact: true)
                )
                .id("\(detail.id)-\(scheme == .dark ? "dark" : "light")")
            } else if let error = model.articleError {
                VStack(spacing: 14) {
                    MobileEmptyState(
                        icon: "doc.text",
                        title: "专栏加载失败",
                        message: error
                    )
                    Button {
                        Task { await model.loadArticle(id: articleID, force: true) }
                    } label: {
                        Text("重试")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.selectedText(scheme))
                            .padding(.horizontal, 22)
                            .frame(height: 40)
                            .background(AppTheme.selected(scheme), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 60)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载专栏…")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background(scheme))
        .navigationTitle("专栏")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if model.activeArticleID != articleID {
                model.openArticle(id: articleID)
            } else if model.articleDetail == nil, !model.isLoadingArticle {
                await model.loadArticle(id: articleID)
            }
        }
        .onDisappear {
            if model.activeArticleID == articleID {
                model.closeArticle()
            }
        }
    }
}

private struct MobileArticleWebView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.bilibili.com"))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedHTML: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
