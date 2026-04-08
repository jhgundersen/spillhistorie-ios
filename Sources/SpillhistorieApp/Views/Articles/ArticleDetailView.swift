import SwiftUI

struct ArticleDetailView: View {
    let articleID: Int
    let fallbackArticle: Article?
    @Environment(ArticleStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var blocks: [ArticleBlock] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    private var article: Article? {
        store.articles.first { $0.id == articleID } ?? fallbackArticle
    }

    var body: some View {
        ScrollView {
            // .id forces full recreation when articleID changes,
            // preventing stale hero images from the previous article.
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                articleBody
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(articleID)
        }
        .navigationTitle(article?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let link = article?.link, let title = article?.title {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: link, subject: Text(title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task(id: articleID) {
            await loadArticle()
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var heroImage: some View {
        if let imageURL = article?.featuredImageURL {
            AsyncImage(url: imageURL) { phase in
                if let img = phase.image {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(uiColor: .systemGray5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: horizontalSizeClass == .compact ? 220 : 280)
            .clipped()
        }
    }

    @ViewBuilder
    private var articleBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article?.title ?? "")
                .font(.title)
                .fontWeight(.bold)
                .fontDesign(settings.fontStyle.design)
                .padding(.top, 20)

            HStack(spacing: 8) {
                if let author = article?.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                if let published = article?.published {
                    Text(published, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider().padding(.vertical, 8)

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Laster innhold…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)
                .frame(maxWidth: .infinity)
            } else if loadFailed {
                ContentUnavailableView(
                    "Kunne ikke laste",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Prøv igjen ved å gå tilbake og åpne artikkelen på nytt.")
                )
            } else {
                ArticleView(blocks: blocks)
                    .fontDesign(settings.fontStyle.design)
            }
        }
        .padding(.horizontal, horizontalSizeClass == .compact ? 22 : 20)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading

    private func loadArticle() async {
        isLoading = true
        loadFailed = false
        blocks = []

        let html: String
        if let existing = article?.contentHTML {
            // Phase 2 already delivered content
            html = existing
        } else {
            // Fetch this article's content directly — don't wait for Phase 2
            guard let enrichments = try? await WordPressAPI.fetchArticleContent(ids: [articleID]),
                  let enrichment = enrichments[articleID]
            else {
                isLoading = false
                loadFailed = true
                return
            }
            // Write back to store so list row also gains author + thumbnail
            store.applyEnrichment(enrichment, toArticleID: articleID)
            html = enrichment.contentHTML
        }

        let captured = html
        blocks = await Task.detached(priority: .userInitiated) {
            HTMLParser.parse(captured)
        }.value
        isLoading = false
    }
}
