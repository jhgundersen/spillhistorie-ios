import SwiftUI

struct HeadingBlockView: View {
    let level: Int
    let text: String

    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(level <= 2 ? .bold : .semibold)
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
    }

    private var font: Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }

    private var topPadding: CGFloat {
        level <= 2 ? 24 : 16
    }
}
