import SwiftUI

struct ListBlockView: View {
    let items: [[InlineSpan]]
    let ordered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, spans in
                HStack(alignment: .top, spacing: 8) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    spans.reduce(Text("")) { partial, span in
                        partial + styledText(for: span)
                    }
                    .font(.system(.body, design: .serif))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func styledText(for span: InlineSpan) -> Text {
        switch span {
        case .text(let s): return Text(s)
        case .bold(let s): return Text(s).bold()
        case .italic(let s): return Text(s).italic()
        case .link(let t, _): return Text(t).foregroundColor(.accentColor)
        case .inlineCode(let s): return Text(s).font(.system(.body, design: .monospaced))
        }
    }
}
