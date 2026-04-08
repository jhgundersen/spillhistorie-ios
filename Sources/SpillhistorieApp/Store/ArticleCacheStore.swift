import Foundation

struct ArticleCacheStore {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let baseDirectory: URL

    init(fileManager: FileManager = .default) {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        baseDirectory = root.appendingPathComponent("ArticleCache", isDirectory: true)
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func loadList(for category: ArticleCategory) -> [Article]? {
        guard let payload: CachedArticleList = load(CachedArticleList.self, from: listURL(for: category)) else {
            return nil
        }
        let enrichments = loadEnrichments(for: payload.articles.map(\Article.id))
        return merge(payload.articles, with: enrichments)
    }

    func saveList(_ articles: [Article], for category: ArticleCategory) {
        save(CachedArticleList(categoryID: category.id, savedAt: Date(), articles: articles), to: listURL(for: category))
    }

    func loadEnrichments(for articleIDs: [Int]) -> [Int: ArticleEnrichment] {
        articleIDs.reduce(into: [Int: ArticleEnrichment]()) { result, id in
            guard let entry: CachedArticleEnrichment = load(CachedArticleEnrichment.self, from: enrichmentURL(for: id)) else {
                return
            }
            result[id] = entry.enrichment
        }
    }

    func saveEnrichment(_ enrichment: ArticleEnrichment, for articleID: Int) {
        save(CachedArticleEnrichment(articleID: articleID, savedAt: Date(), enrichment: enrichment), to: enrichmentURL(for: articleID))
    }

    private func merge(_ articles: [Article], with enrichments: [Int: ArticleEnrichment]) -> [Article] {
        articles.map { article in
            guard let enrichment = enrichments[article.id] else { return article }
            var merged = article
            merged.author = enrichment.author ?? article.author
            merged.contentHTML = enrichment.contentHTML
            merged.featuredImageURL = enrichment.featuredImageURL ?? article.featuredImageURL
            return merged
        }
    }

    private func listURL(for category: ArticleCategory) -> URL {
        baseDirectory.appendingPathComponent("list-\(category.id).json")
    }

    private func enrichmentURL(for articleID: Int) -> URL {
        baseDirectory.appendingPathComponent("article-\(articleID).json")
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

private struct CachedArticleList: Codable {
    let categoryID: String
    let savedAt: Date
    let articles: [Article]
}

private struct CachedArticleEnrichment: Codable {
    let articleID: Int
    let savedAt: Date
    let enrichment: ArticleEnrichment
}
