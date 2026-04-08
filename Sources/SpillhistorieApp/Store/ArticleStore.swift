import Foundation

@MainActor
@Observable
final class ArticleStore {
    var articles: [Article] = []
    var isLoadingList = false
    var isLoadingContent = false
    var error: String?
    var selectedCategory: ArticleCategory = ArticleCategory.all[0]
    private let cacheStore = ArticleCacheStore()

    func loadCategory(_ category: ArticleCategory, forceRefresh: Bool = false) async {
        selectedCategory = category
        error = nil

        let cachedArticles = cacheStore.loadList(for: category) ?? []
        if !cachedArticles.isEmpty {
            articles = cachedArticles
        }

        isLoadingList = articles.isEmpty || forceRefresh

        do {
            let list = try await WordPressAPI.fetchArticleList(category: category)
            let cachedEnrichments = cacheStore.loadEnrichments(for: list.map(\Article.id))
            let mergedList = merge(list, with: cachedEnrichments)
            articles = mergedList
            cacheStore.saveList(mergedList, for: category)
            isLoadingList = false
            Task { await self.loadContent(for: mergedList, category: category) }
        } catch {
            if articles.isEmpty {
                self.error = error.localizedDescription
            }
            isLoadingList = false
        }
    }

    private func loadContent(for list: [Article], category: ArticleCategory) async {
        isLoadingContent = true
        let ids = list.map { $0.id }
        guard let enrichments = try? await WordPressAPI.fetchArticleContent(ids: ids) else {
            isLoadingContent = false
            return
        }
        articles = merge(articles, with: enrichments)
        cacheStore.saveList(articles, for: category)
        for (id, enrichment) in enrichments {
            cacheStore.saveEnrichment(enrichment, for: id)
        }
        isLoadingContent = false
    }

    func applyEnrichment(_ enrichment: ArticleEnrichment, toArticleID id: Int) {
        articles = merge(articles, with: [id: enrichment])
        cacheStore.saveEnrichment(enrichment, for: id)
        cacheStore.saveList(articles, for: selectedCategory)
    }

    func refresh() async {
        await loadCategory(selectedCategory, forceRefresh: true)
    }

    private func merge(_ articles: [Article], with enrichments: [Int: ArticleEnrichment]) -> [Article] {
        articles.map { article in
            guard let enrichment = enrichments[article.id] else { return article }
            var updated = article
            updated.author = enrichment.author ?? article.author
            updated.contentHTML = enrichment.contentHTML
            updated.featuredImageURL = enrichment.featuredImageURL ?? article.featuredImageURL
            return updated
        }
    }
}
