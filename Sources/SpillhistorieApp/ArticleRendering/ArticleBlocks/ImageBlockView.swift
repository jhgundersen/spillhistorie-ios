import SwiftUI

struct ImageBlockView: View {
    let src: URL
    let alt: String
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: src) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Color(uiColor: .systemGray5)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                case .empty:
                    Color(uiColor: .systemGray5)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay { ProgressView() }
                @unknown default:
                    EmptyView()
                }
            }
            if let caption = caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            } else if !alt.isEmpty {
                Text(alt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
