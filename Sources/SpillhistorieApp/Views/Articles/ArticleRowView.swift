import SwiftUI

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Featured image thumbnail
            if let imageURL = article.featuredImageURL {
                AsyncImage(url: imageURL) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(uiColor: .systemGray5)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .systemGray5))
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                    .foregroundStyle(Color.primary)

                HStack(spacing: 6) {
                    if let author = article.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(article.published, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}
