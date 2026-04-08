import SwiftUI

struct ParagraphBlockView: View {
    let inlines: [InlineSpan]

    var body: some View {
        inlines.reduce(Text("")) { partial, span in
            partial + styledText(for: span)
        }
        .font(.system(.body, design: .serif))
        .lineSpacing(4)
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func styledText(for span: InlineSpan) -> Text {
        switch span {
        case .text(let s):
            return Text(s)
        case .bold(let s):
            return Text(s).bold()
        case .italic(let s):
            return Text(s).italic()
        case .link(let t, _):
            // Links rendered as tinted text (tappable links need AttributedString — kept simple here)
            return Text(t).foregroundColor(.accentColor)
        case .inlineCode(let s):
            return Text(s).font(.system(.body, design: .monospaced))
        }
    }
}
