import SwiftUI

struct ArticleView: View {
    let blocks: [ArticleBlock]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                ArticleBlockView(block: block)
                    .padding(.bottom, blockBottomPadding(block))
            }
        }
    }

    private func blockBottomPadding(_ block: ArticleBlock) -> CGFloat {
        switch block {
        case .heading: return 8
        case .paragraph: return 14
        case .image: return 16
        case .blockquote: return 16
        case .codeBlock: return 16
        case .unorderedList, .orderedList: return 14
        case .divider: return 24
        }
    }
}

struct ArticleBlockView: View {
    let block: ArticleBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            HeadingBlockView(level: level, text: text)
        case .paragraph(let inlines):
            ParagraphBlockView(inlines: inlines)
        case .image(let src, let alt, let caption):
            ImageBlockView(src: src, alt: alt, caption: caption)
        case .blockquote(let blocks):
            BlockquoteBlockView(blocks: blocks)
        case .codeBlock(let text):
            CodeBlockView(text: text)
        case .unorderedList(let items):
            ListBlockView(items: items, ordered: false)
        case .orderedList(let items):
            ListBlockView(items: items, ordered: true)
        case .divider:
            Divider()
                .padding(.vertical, 8)
        }
    }
}
