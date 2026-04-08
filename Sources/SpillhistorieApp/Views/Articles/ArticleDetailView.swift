import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    @State private var blocks: [ArticleBlock] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Hero image
                if let imageURL = article.featuredImageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color(uiColor: .systemGray5).frame(height: 280)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    // Meta: author + date
                    HStack(spacing: 8) {
                        if let author = article.author {
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(article.published, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Article body
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Laster…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 32)
                        .frame(maxWidth: .infinity)
                    } else if blocks.isEmpty {
                        ContentUnavailableView(
                            "Ingen innhold",
                            systemImage: "doc.text",
                            description: Text("Innholdet kunne ikke lastes.")
                        )
                    } else {
                        ArticleView(blocks: blocks)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: article.link, subject: Text(article.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task(id: article.id) {
            await loadContent()
        }
    }

    private func loadContent() async {
        isLoading = true
        if let html = article.contentHTML {
            let capturedHTML = html
            blocks = await Task.detached(priority: .userInitiated) {
                HTMLParser.parse(capturedHTML)
            }.value
        } else {
            // Content not yet enriched — wait a bit and retry
            try? await Task.sleep(for: .seconds(1.5))
            if let html = article.contentHTML {
                let capturedHTML = html
                blocks = await Task.detached(priority: .userInitiated) {
                    HTMLParser.parse(capturedHTML)
                }.value
            }
        }
        isLoading = false
    }
}
