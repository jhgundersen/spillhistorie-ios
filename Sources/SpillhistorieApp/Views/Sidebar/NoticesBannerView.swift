import SwiftUI

struct NoticesBannerView: View {
    let notices: [Notice]
    @State private var currentIndex = 0
    @State private var opacity: Double = 1

    var body: some View {
        if let notice = notices.indices.contains(currentIndex) ? notices[currentIndex] : notices.first {
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                Text(notice.excerpt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 8)
            .opacity(opacity)
            .task {
                guard notices.count > 1 else { return }
                while true {
                    try? await Task.sleep(for: .seconds(8))
                    withAnimation(.easeOut(duration: 0.4)) { opacity = 0 }
                    try? await Task.sleep(for: .seconds(0.4))
                    currentIndex = (currentIndex + 1) % notices.count
                    withAnimation(.easeIn(duration: 0.4)) { opacity = 1 }
                }
            }
        }
    }
}
