import Foundation

@MainActor
@Observable
final class ArticleStore {
    var articles: [Article] = []
    var isLoadingList = false
    var isLoadingContent = false
    var error: String?
    var selectedCategory: ArticleCategory = ArticleCategory.all[0]

    func loadCategory(_ category: ArticleCategory) async {
        selectedCategory = category
        isLoadingList = true
        error = nil
        do {
            let list = try await WordPressAPI.fetchArticleList(category: category)
            articles = list
            isLoadingList = false
            Task { await self.loadContent(for: list) }
        } catch {
            self.error = error.localizedDescription
            isLoadingList = false
        }
    }

    private func loadContent(for list: [Article]) async {
        isLoadingContent = true
        let ids = list.map { $0.id }
        guard let enrichments = try? await WordPressAPI.fetchArticleContent(ids: ids) else {
            isLoadingContent = false
            return
        }
        articles = articles.map { article in
            guard let enrichment = enrichments[article.id] else { return article }
            var updated = article
            updated.author = enrichment.author
            updated.contentHTML = enrichment.contentHTML
            updated.featuredImageURL = enrichment.featuredImageURL
            return updated
        }
        isLoadingContent = false
    }

    func applyEnrichment(_ enrichment: ArticleEnrichment, toArticleID id: Int) {
        articles = articles.map { article in
            guard article.id == id else { return article }
            var updated = article
            updated.author = enrichment.author
            updated.contentHTML = enrichment.contentHTML
            updated.featuredImageURL = enrichment.featuredImageURL
            return updated
        }
    }

    func refresh() async {
        await loadCategory(selectedCategory)
    }
}
