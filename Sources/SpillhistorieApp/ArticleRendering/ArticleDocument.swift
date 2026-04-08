import Foundation

// MARK: - Block types
// Note: NOT Identifiable — ForEach uses enumerated() with index as id to guarantee stability.

indirect enum ArticleBlock {
    case heading(level: Int, text: String)
    case paragraph(inlines: [InlineSpan])
    case image(src: URL, alt: String, caption: String?)
    case blockquote(blocks: [ArticleBlock])
    case codeBlock(text: String)
    case unorderedList(items: [[InlineSpan]])
    case orderedList(items: [[InlineSpan]])
    case divider
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
