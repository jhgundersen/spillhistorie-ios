import SwiftUI

struct BlockquoteBlockView: View {
    let blocks: [ArticleBlock]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    ArticleBlockView(block: block)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 4)
    }
}
