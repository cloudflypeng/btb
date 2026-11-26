import AppKit
import SwiftUI
import WebKit

struct ArticleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let detail = model.articleDetail {
                ArticleWebView(
                    html: ArticleHTMLBuilder.html(for: detail, scheme: scheme)
                )
                .id("\(detail.id)-\(scheme == .dark ? "dark" : "light")")
            } else if let error = model.articleError {
                VStack(spacing: 18) {
                    EmptyHint(
                        icon: "doc.text",
                        title: "专栏加载失败",
                        message: error
                    )
                    Button("重试") {
                        Task { await model.loadArticle(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brand)
                }
                .padding(40)
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
    }
}

private struct ArticleWebView: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.underPageBackgroundColor = .clear
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
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
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
