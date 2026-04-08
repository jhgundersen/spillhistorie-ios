import Foundation
import SwiftSoup

enum HTMLParser {
    static func parse(_ html: String) -> [ArticleBlock] {
        guard !html.isEmpty, let doc = try? SwiftSoup.parse(html) else { return [] }
        // Prefer the article body or entry-content wrapper; fall back to full body
        let body: Element
        if let article = try? doc.select("article").first() {
            body = article
        } else if let entry = try? doc.select(".entry-content").first() {
            body = entry
        } else if let b = doc.body() {
            body = b
        } else {
            return []
        }
        return parseChildrenFlat(of: body)
    }

    // MARK: - Container flattening
    // div/section/aside containers are transparent — their children are inlined.
    // This handles Gutenberg's wrapper-heavy HTML without producing empty blocks.

    static func parseChildrenFlat(of element: Element) -> [ArticleBlock] {
        var blocks: [ArticleBlock] = []
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if isTransparentContainer(tag) {
                blocks.append(contentsOf: parseChildrenFlat(of: child))
            } else if let block = parseElement(child) {
                blocks.append(block)
            }
        }
        return blocks
    }

    private static func isTransparentContainer(_ tag: String) -> Bool {
        ["div", "section", "aside", "main", "span"].contains(tag)
    }

    // MARK: - Element parsing

    private static func parseElement(_ el: Element) -> ArticleBlock? {
        let tag = el.tagName().lowercased()
        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(tag.dropFirst()) ?? 2
            let text = (try? el.text()) ?? ""
            return text.isEmpty ? nil : .heading(level: level, text: text)

        case "p":
            return parseParagraph(el)

        case "figure":
            if let img = try? el.select("img").first() {
                let caption = (try? el.select("figcaption").text()) ?? ""
                return parseImage(img, caption: caption.isEmpty ? nil : caption)
            }
            if let media = parseEmbeddedMedia(el) {
                return media
            }
            // figure with no img — try as blockquote or skip
            return nil

        case "img":
            return parseImage(el)

        case "audio":
            return parseAudio(el)

        case "video":
            return parseVideo(el)

        case "iframe":
            return parseEmbed(el)

        case "blockquote":
            let inner = parseChildrenFlat(of: el)
            // If it's empty, try treating the text as a single paragraph
            if inner.isEmpty {
                let text = (try? el.text()) ?? ""
                if text.isEmpty { return nil }
                return .blockquote(blocks: [.paragraph(inlines: [.text(text)])])
            }
            return .blockquote(blocks: inner)

        case "pre":
            return .codeBlock(text: (try? el.text()) ?? "")

        case "code":
            // Standalone <code> (not inside <pre>) — treat as code block
            guard el.parent()?.tagName().lowercased() != "pre" else { return nil }
            return .codeBlock(text: (try? el.text()) ?? "")

        case "ul":
            let items = (try? el.select("> li").array()) ?? []
            let parsed = items.map { parseInlines($0) }.filter { !$0.isEmpty }
            return parsed.isEmpty ? nil : .unorderedList(items: parsed)

        case "ol":
            let items = (try? el.select("> li").array()) ?? []
            let parsed = items.map { parseInlines($0) }.filter { !$0.isEmpty }
            return parsed.isEmpty ? nil : .orderedList(items: parsed)

        case "hr":
            return .divider

        case "table":
            // Tables: render as a plain text block rather than crashing
            let text = (try? el.text()) ?? ""
            return text.isEmpty ? nil : .paragraph(inlines: [.text(text)])

        case "script", "style", "noscript", "form", "nav", "header", "footer":
            return nil

        default:
            // Any unknown block-level element: try to extract text
            let text = (try? el.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? nil : .paragraph(inlines: [.text(text)])
        }
    }

    // MARK: - Paragraph parsing

    private static func parseParagraph(_ el: Element) -> ArticleBlock? {
        if let media = parseEmbeddedMedia(el) {
            return media
        }
        // If paragraph contains an <img> (directly or inside <a>), emit it as an image block
        let imgs = (try? el.select("img").array()) ?? []
        if !imgs.isEmpty {
            let hasOnlyMedia = (try? el.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ?? true
            if hasOnlyMedia, let img = imgs.first {
                return parseImage(img)
            }
        }
        let inlines = parseInlines(el)
        return inlines.isEmpty ? nil : .paragraph(inlines: inlines)
    }

    // MARK: - Inline spans

    private static func parseInlines(_ el: Element) -> [InlineSpan] {
        var spans: [InlineSpan] = []
        for node in el.getChildNodes() {
            if let textNode = node as? TextNode {
                let text = textNode.text()
                if !text.isEmpty { spans.append(.text(text)) }
            } else if let child = node as? Element {
                spans.append(contentsOf: parseInlineElement(child))
            }
        }
        return spans
    }

    private static func parseInlineElement(_ el: Element) -> [InlineSpan] {
        let tag = el.tagName().lowercased()
        let text = (try? el.text()) ?? ""

        switch tag {
        case "strong", "b":
            return text.isEmpty ? [] : [.bold(text)]
        case "em", "i":
            return text.isEmpty ? [] : [.italic(text)]
        case "a":
            if let href = try? el.attr("href"), let url = URL(string: href), !text.isEmpty {
                return [.link(text: text, href: url)]
            }
            // Anchor wrapping an image — skip (handled by parseParagraph)
            return text.isEmpty ? [] : [.text(text)]
        case "code":
            return text.isEmpty ? [] : [.inlineCode(text)]
        case "br":
            return [.text("\n")]
        case "img", "picture":
            // Inline images inside text — skip, parseParagraph handles top-level imgs
            return []
        case "span", "mark", "s", "del", "ins", "sup", "sub", "small", "abbr", "cite":
            // Recurse into formatting spans
            return parseInlines(el)
        default:
            return text.isEmpty ? [] : [.text(text)]
        }
    }

    // MARK: - Image extraction

    private static func parseEmbeddedMedia(_ el: Element) -> ArticleBlock? {
        if let audio = try? el.select("audio").first(), let block = parseAudio(audio) {
            return block
        }
        if let video = try? el.select("video").first(), let block = parseVideo(video) {
            return block
        }
        if let iframe = try? el.select("iframe").first(), let block = parseEmbed(iframe) {
            return block
        }
        if let mediaLink = parseMediaLink(el) {
            return mediaLink
        }
        return nil
    }

    private static func parseMediaLink(_ el: Element) -> ArticleBlock? {
        let links = (try? el.select("a").array()) ?? []
        guard links.count == 1, let link = links.first else { return nil }
        let text = ((try? el.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard let href = try? link.attr("href") else { return nil }
        return blockForMediaURLString(href, title: text)
    }

    private static func parseAudio(_ el: Element) -> ArticleBlock? {
        if let source = firstSourceURL(in: el) {
            return .audio(src: source)
        }
        if let src = try? el.attr("src"), !src.isEmpty,
           let url = URL(string: ensureHTTPS(src.htmlDecoded)) {
            return .audio(src: url)
        }
        return nil
    }

    private static func parseVideo(_ el: Element) -> ArticleBlock? {
        let videoURL: URL?
        if let source = firstSourceURL(in: el) {
            videoURL = source
        } else if let src = try? el.attr("src"), !src.isEmpty {
            videoURL = URL(string: ensureHTTPS(src.htmlDecoded))
        } else {
            videoURL = nil
        }
        guard let videoURL else { return nil }

        let poster: URL?
        if let posterAttr = try? el.attr("poster"), !posterAttr.isEmpty {
            poster = URL(string: ensureHTTPS(posterAttr.htmlDecoded))
        } else {
            poster = nil
        }

        return .video(src: videoURL, poster: poster)
    }

    private static func parseEmbed(_ el: Element) -> ArticleBlock? {
        guard let src = try? el.attr("src"), !src.isEmpty else { return nil }
        let title = (try? el.attr("title")).flatMap { $0.isEmpty ? nil : $0 }
        return blockForMediaURLString(src, title: title)
    }

    private static func blockForMediaURLString(_ urlString: String, title: String?) -> ArticleBlock? {
        let decoded = ensureHTTPS(urlString.htmlDecoded)
        guard let url = URL(string: decoded) else { return nil }
        let lowercased = decoded.lowercased()
        if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            return .embed(src: normalizedYouTubeURL(from: url) ?? url, title: title)
        }
        if lowercased.contains(".mp3") {
            return .audio(src: url)
        }
        if lowercased.contains(".mp4") {
            return .video(src: url, poster: nil)
        }
        return nil
    }

    private static func firstSourceURL(in el: Element) -> URL? {
        let sources = (try? el.select("source").array()) ?? []
        for source in sources {
            if let src = try? source.attr("src"), !src.isEmpty,
               let url = URL(string: ensureHTTPS(src.htmlDecoded)) {
                return url
            }
        }
        return nil
    }

    private static func normalizedYouTubeURL(from url: URL) -> URL? {
        let absolute = url.absoluteString
        if absolute.contains("/embed/") {
            return url
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        if let host = components.host, host.contains("youtu.be"), let videoID = components.path.split(separator: "/").last {
            return URL(string: "https://www.youtube.com/embed/\(videoID)")
        }
        if let item = components.queryItems?.first(where: { $0.name == "v" }), let videoID = item.value {
            return URL(string: "https://www.youtube.com/embed/\(videoID)")
        }
        return url
    }

    private static func parseImage(_ img: Element, caption: String? = nil) -> ArticleBlock? {
        guard let src = bestSrc(from: img), let url = URL(string: ensureHTTPS(src)) else { return nil }
        // Skip tiny tracking pixels (width/height <= 1)
        if let w = (try? img.attr("width")), let wInt = Int(w), wInt <= 1 { return nil }
        if let h = (try? img.attr("height")), let hInt = Int(h), hInt <= 1 { return nil }
        let alt = (try? img.attr("alt")) ?? ""
        return .image(src: url, alt: alt, caption: caption)
    }

    /// Mirror TUI's bestImgSrc logic — tries each lazy-load attribute in order, then srcset.
    private static func bestSrc(from img: Element) -> String? {
        let candidates = ["src", "data-src", "data-lazy-src", "data-original", "data-full-url"]
        for attr in candidates {
            if let val = try? img.attr(attr), !val.isEmpty, !val.hasPrefix("data:") {
                return val
            }
        }
        if let srcset = try? img.attr("srcset"), !srcset.isEmpty {
            // Pick the largest image from srcset (last entry typically has the highest descriptor)
            let entries = srcset.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
                  .split(separator: " ", maxSplits: 1)
                  .first.map(String.init) ?? ""
            }.filter { !$0.isEmpty }
            return entries.last ?? entries.first
        }
        return nil
    }

    private static func ensureHTTPS(_ urlString: String) -> String {
        urlString.hasPrefix("//") ? "https:" + urlString : urlString
    }
}
