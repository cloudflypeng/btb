import SwiftUI

enum ArticleHTMLBuilder {
    static func html(for detail: ArticleDetail, scheme: ColorScheme, compact: Bool = false) -> String {
        let dark = scheme == .dark
        let background = dark ? "#141416" : "#ffffff"
        let text = dark ? "#e8e8ea" : "#18181b"
        let secondary = dark ? "#9d9da3" : "#6b6b70"
        let divider = dark ? "#2c2c30" : "#e8e8ea"
        let card = dark ? "#1e1e21" : "#f5f5f6"
        let link = dark ? "#79b8ff" : "#0b66c3"

        let authorName = escaped(detail.author?.name ?? "未知作者")
        let avatarURL = detail.author?.avatarURL?.absoluteString
        let avatar = avatarURL.map {
            "<img class=\"avatar\" src=\"\(escaped($0))\" alt=\"\">"
        } ?? ""

        var metaParts: [String] = []
        if let category = detail.category?.name, !category.isEmpty {
            metaParts.append("<span class=\"badge\">\(escaped(category))</span>")
        }
        if !detail.publishedText.isEmpty {
            metaParts.append("<span>\(escaped(detail.publishedText))</span>")
        }
        if !detail.statsText.isEmpty {
            metaParts.append("<span>\(escaped(detail.statsText))</span>")
        }

        let banner = detail.bannerLink.map {
            "<img class=\"banner\" src=\"\(escaped($0.absoluteString))\" alt=\"\">"
        } ?? ""

        let contentSource = detail.content?.isEmpty == false
            ? detail.content!
            : "<p>\(escaped(detail.summary ?? ""))</p>"
        let content = sanitizedContent(contentSource)

        let mainPadding = compact ? "24px 18px 70px" : "40px 34px 90px"
        let titleSize = compact ? "26px" : "30px"
        let bodySize = compact ? "17px" : "16px"

        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: \(dark ? "dark" : "light"); }
        * { box-sizing: border-box; }
        html, body { margin: 0; padding: 0; }
        body {
            background: \(background);
            color: \(text);
            font: \(bodySize)/1.85 -apple-system, "PingFang SC", "Hiragino Sans GB", "Helvetica Neue", sans-serif;
            -webkit-font-smoothing: antialiased;
        }
        main { max-width: 780px; margin: 0 auto; padding: \(mainPadding); }
        h1.title {
            font-size: \(titleSize);
            line-height: 1.32;
            font-weight: 700;
            letter-spacing: -0.02em;
            margin: 0 0 16px;
        }
        .meta {
            display: flex;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
            color: \(secondary);
            font-size: 13px;
            margin-bottom: 26px;
        }
        .meta .avatar { width: 34px; height: 34px; border-radius: 50%; object-fit: cover; }
        .meta .author { color: \(text); font-weight: 600; font-size: 14px; }
        .badge {
            background: \(card);
            color: \(secondary);
            padding: 2px 10px;
            border-radius: 999px;
            font-size: 12px;
        }
        .banner { width: 100%; height: auto; border-radius: 14px; margin: 4px 0 28px; display: block; }
        article { font-size: \(bodySize); overflow-wrap: break-word; }
        article p { margin: 0 0 1.15em; }
        article h1, article h2, article h3, article h4 {
            line-height: 1.42;
            margin: 1.7em 0 0.7em;
            font-weight: 700;
        }
        article h1 { font-size: 24px; }
        article h2 { font-size: 21px; }
        article h3 { font-size: 18px; }
        article img {
            max-width: 100%;
            height: auto !important;
            display: block;
            margin: 1.2em auto;
            border-radius: 10px;
        }
        article figure { margin: 1.3em 0; }
        article figcaption { color: \(secondary); font-size: 12.5px; text-align: center; margin-top: 7px; }
        article a { color: \(link); text-decoration: none; }
        article a:hover { text-decoration: underline; }
        article blockquote {
            border-left: 3px solid \(link);
            margin: 1.3em 0;
            padding: 0.2em 0 0.2em 1em;
            color: \(secondary);
        }
        article pre, article code {
            background: \(card);
            border-radius: 7px;
            padding: 2px 6px;
            font-family: ui-monospace, Menlo, monospace;
            font-size: 14px;
        }
        article pre { padding: 12px 14px; overflow-x: auto; }
        article pre code { padding: 0; background: transparent; }
        article hr { border: 0; border-top: 1px solid \(divider); margin: 2em 0; }
        article table { border-collapse: collapse; max-width: 100%; }
        article td, article th { border: 1px solid \(divider); padding: 6px 10px; }
        article video, article iframe, article .video-card, article .bili-video-card { display: none; }
        footer {
            margin-top: 46px;
            padding-top: 18px;
            border-top: 1px solid \(divider);
            color: \(secondary);
            font-size: 12.5px;
            display: flex;
            justify-content: space-between;
            gap: 12px;
        }
        footer a { color: \(link); text-decoration: none; }
        </style>
        </head>
        <body>
        <main>
        <header>
        <h1 class="title">\(escaped(detail.title))</h1>
        <div class="meta">
        \(avatar)
        <span class="author">\(authorName)</span>
        \(metaParts.joined(separator: "<span>·</span>"))
        </div>
        </header>
        \(banner)
        <article>
        \(content)
        </article>
        <footer>
        <span>专栏 cv\(detail.id)</span>
        <a href="https://www.bilibili.com/read/cv\(detail.id)">在浏览器中打开</a>
        </footer>
        </main>
        </body>
        </html>
        """
    }

    private static func sanitizedContent(_ raw: String) -> String {
        var value = raw
        value = value.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        value = value.replacingOccurrences(
            of: "<iframe[^>]*>[\\s\\S]*?</iframe>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        value = value.replacingOccurrences(of: "src=\"//", with: "src=\"https://")
        value = value.replacingOccurrences(of: "href=\"//", with: "href=\"https://")
        value = value.replacingOccurrences(of: "src=\"http://", with: "src=\"https://")
        return value
    }

    private static func escaped(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
