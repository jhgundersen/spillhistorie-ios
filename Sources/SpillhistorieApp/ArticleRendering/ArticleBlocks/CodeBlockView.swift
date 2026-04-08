import SwiftUI

struct CodeBlockView: View {
    let text: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Color.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
