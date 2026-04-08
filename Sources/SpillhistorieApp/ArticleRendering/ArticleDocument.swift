import Foundation

// MARK: - Block types

indirect enum ArticleBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(inlines: [InlineSpan])
    case image(src: URL, alt: String, caption: String?)
    case blockquote(blocks: [ArticleBlock])
    case codeBlock(text: String)
    case unorderedList(items: [[InlineSpan]])
    case orderedList(items: [[InlineSpan]])
    case divider

    var id: String {
        switch self {
        case .heading(let level, let text): return "h\(level)-\(text.prefix(40))"
        case .paragraph(let inlines): return "p-\(inlines.first?.text.prefix(40) ?? "")"
        case .image(let src, _, _): return "img-\(src.absoluteString)"
        case .blockquote: return "bq-\(UUID())"
        case .codeBlock(let text): return "code-\(text.prefix(40))"
        case .unorderedList: return "ul-\(UUID())"
        case .orderedList: return "ol-\(UUID())"
        case .divider: return "hr-\(UUID())"
        }
    }
}

enum InlineSpan {
    case text(String)
    case bold(String)
    case italic(String)
    case link(text: String, href: URL)
    case inlineCode(String)

    var text: String {
        switch self {
        case .text(let s), .bold(let s), .italic(let s), .inlineCode(let s): return s
        case .link(let t, _): return t
        }
    }
}
