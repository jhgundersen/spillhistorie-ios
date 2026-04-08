import Foundation
import SwiftSoup

enum HTMLParser {
    static func parse(_ html: String) -> [ArticleBlock] {
        guard let doc = try? SwiftSoup.parse(html) else { return [] }
        // Try to get article body content
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
        return parseChildren(of: body)
    }

    // MARK: - Node traversal

    private static func parseChildren(of element: Element) -> [ArticleBlock] {
        var blocks: [ArticleBlock] = []
        for child in element.children() {
            if let block = parseElement(child) {
                blocks.append(block)
            }
        }
        return blocks
    }

    private static func parseElement(_ el: Element) -> ArticleBlock? {
        let tag = el.tagName().lowercased()
        switch tag {
        case "h1": return .heading(level: 1, text: (try? el.text()) ?? "")
        case "h2": return .heading(level: 2, text: (try? el.text()) ?? "")
        case "h3": return .heading(level: 3, text: (try? el.text()) ?? "")
        case "h4": return .heading(level: 4, text: (try? el.text()) ?? "")
        case "h5": return .heading(level: 5, text: (try? el.text()) ?? "")
        case "h6": return .heading(level: 6, text: (try? el.text()) ?? "")

        case "p":
            // Check if the paragraph contains only an image
            let imgs = (try? el.select("img").array()) ?? []
            if imgs.count == 1, (try? el.text().trimmingCharacters(in: .whitespacesAndNewlines)) == "" || imgs.count == el.children().count {
                if let img = imgs.first, let block = parseImage(img) { return block }
            }
            let inlines = parseInlines(el)
            if inlines.isEmpty { return nil }
            return .paragraph(inlines: inlines)

        case "figure":
            if let img = (try? el.select("img").first()) {
                let caption = (try? el.select("figcaption").first()?.text()) ?? ""
                return parseImage(img, caption: caption.isEmpty ? nil : caption)
            }
            return nil

        case "img":
            return parseImage(el)

        case "blockquote":
            let children = parseChildren(of: el)
            return children.isEmpty ? nil : .blockquote(blocks: children)

        case "pre", "code":
            return .codeBlock(text: (try? el.text()) ?? "")

        case "ul":
            let items = (try? el.select("li").array()) ?? []
            let parsed = items.map { parseInlines($0) }
            return .unorderedList(items: parsed)

        case "ol":
            let items = (try? el.select("li").array()) ?? []
            let parsed = items.map { parseInlines($0) }
            return .orderedList(items: parsed)

        case "hr":
            return .divider

        case "div", "section", "article", "aside":
            // Recurse into container elements
            let children = parseChildren(of: el)
            if children.count == 1 { return children[0] }
            // Multiple children: flatten them — caller appends individually
            // We can't return multiple blocks, so return a paragraph with combined text as fallback
            // Actually, use a special wrapping approach: return the first child if only one, else recurse by returning nil and appending externally
            // The caller iterates children directly, so this div is treated as a container.
            // Return nil here; we handle divs by flattening in parseChildren override below.
            return nil

        default:
            // Try to extract text as paragraph
            guard let text = try? el.text(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .paragraph(inlines: [.text(text)])
        }
    }

    // MARK: - Container div flattening

    static func parseChildrenFlat(of element: Element) -> [ArticleBlock] {
        var blocks: [ArticleBlock] = []
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if ["div", "section", "article", "aside"].contains(tag) {
                blocks.append(contentsOf: parseChildrenFlat(of: child))
            } else if let block = parseElement(child) {
                blocks.append(block)
            }
        }
        return blocks
    }

    // MARK: - Inline spans

    private static func parseInlines(_ el: Element) -> [InlineSpan] {
        var spans: [InlineSpan] = []
        for node in el.getChildNodes() {
            if let textNode = node as? TextNode {
                let text = textNode.text()
                if !text.isEmpty { spans.append(.text(text)) }
            } else if let element = node as? Element {
                let tag = element.tagName().lowercased()
                let text = (try? element.text()) ?? ""
                switch tag {
                case "strong", "b":
                    spans.append(.bold(text))
                case "em", "i":
                    spans.append(.italic(text))
                case "a":
                    if let href = (try? element.attr("href")), let url = URL(string: href) {
                        spans.append(.link(text: text, href: url))
                    } else {
                        spans.append(.text(text))
                    }
                case "code":
                    spans.append(.inlineCode(text))
                case "br":
                    spans.append(.text("\n"))
                default:
                    if !text.isEmpty { spans.append(.text(text)) }
                }
            }
        }
        return spans
    }

    // MARK: - Image extraction

    private static func parseImage(_ img: Element, caption: String? = nil) -> ArticleBlock? {
        guard let src = bestSrc(from: img), let url = URL(string: ensureHTTPS(src)) else { return nil }
        let alt = (try? img.attr("alt")) ?? ""
        return .image(src: url, alt: alt, caption: caption)
    }

    /// Mirror TUI's bestImgSrc logic from render.go
    private static func bestSrc(from img: Element) -> String? {
        let candidates = ["src", "data-src", "data-lazy-src", "data-original"]
        for attr in candidates {
            if let val = try? img.attr(attr), !val.isEmpty, !val.hasPrefix("data:") {
                return val
            }
        }
        // Parse srcset: take first URL
        if let srcset = try? img.attr("srcset"), !srcset.isEmpty {
            let first = srcset.split(separator: ",").first?
                .trimmingCharacters(in: .whitespaces)
                .split(separator: " ").first
            if let first, !first.isEmpty {
                return String(first)
            }
        }
        return nil
    }

    private static func ensureHTTPS(_ urlString: String) -> String {
        if urlString.hasPrefix("//") { return "https:" + urlString }
        return urlString
    }
}
