import Foundation

@Observable
final class ArticleStore {
    var articles: [Article] = []
    var isLoadingList = false
    var isLoadingContent = false
    var error: String?
    var notices: [Notice] = []
    var selectedCategory: ArticleCategory = ArticleCategory.all[0]

    private var contentCache: [Int: ArticleEnrichment] = [:]

    func loadCategory(_ category: ArticleCategory) async {
        selectedCategory = category
        isLoadingList = true
        error = nil
        do {
            let list = try await WordPressAPI.fetchArticleList(category: category)
            articles = list
            isLoadingList = false
            // Phase 2: background content fetch
            Task { await loadContent(for: list) }
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
                contentCache[articles[i].id] = e
            }
        }
        isLoadingContent = false
    }

    func loadNotices() async {
        notices = (try? await WordPressAPI.fetchNotices()) ?? []
    }

    func refresh() async {
        await loadCategory(selectedCategory)
    }
}
