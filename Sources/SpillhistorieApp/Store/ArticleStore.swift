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
        for i in articles.indices {
            if let e = enrichments[articles[i].id] {
                articles[i].author = e.author
                articles[i].contentHTML = e.contentHTML
                articles[i].featuredImageURL = e.featuredImageURL
            }
        }
        isLoadingContent = false
    }

    func applyEnrichment(_ enrichment: ArticleEnrichment, toArticleID id: Int) {
        guard let idx = articles.firstIndex(where: { $0.id == id }) else { return }
        articles[idx].author = enrichment.author
        articles[idx].contentHTML = enrichment.contentHTML
        articles[idx].featuredImageURL = enrichment.featuredImageURL
    }

    func refresh() async {
        await loadCategory(selectedCategory)
    }
}
