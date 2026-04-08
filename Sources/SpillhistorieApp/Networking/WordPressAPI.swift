import Foundation

enum WordPressAPI {
    private static let base = URL(string: "https://www.spillhistorie.no/wp-json/wp/v2")!

    // MARK: - Phase 1: fast list fetch (titles + list metadata + thumbnails)

    static func fetchArticleList(category: ArticleCategory) async throws -> [Article] {
        var components = URLComponents(url: base.appendingPathComponent("posts"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "_fields", value: "id,link,date,title,tags,_links,_embedded"),
            URLQueryItem(name: "_embed", value: "author,wp:featuredmedia"),
            URLQueryItem(name: "per_page", value: "20"),
        ]
        if let catID = category.wpCategoryID {
            items.append(URLQueryItem(name: "categories", value: "\(catID)"))
        }
        if !category.tagIDs.isEmpty {
            items.append(URLQueryItem(name: "tags", value: category.tagIDs.map { "\($0)" }.joined(separator: ",")))
        }
        components.queryItems = items
        let raw = try await NetworkClient.fetch(components.url!, as: [WPPost].self)
        return raw.compactMap { Article(from: $0) }
    }

    // MARK: - Phase 2: background content + author + featured image

    static func fetchArticleContent(ids: [Int]) async throws -> [Int: ArticleEnrichment] {
        guard !ids.isEmpty else { return [:] }
        var components = URLComponents(url: base.appendingPathComponent("posts"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "_fields", value: "id,content,_links,_embedded"),
            URLQueryItem(name: "_embed", value: "author,wp:featuredmedia"),
            URLQueryItem(name: "per_page", value: "\(ids.count)"),
            URLQueryItem(name: "include", value: ids.map { "\($0)" }.joined(separator: ",")),
        ]
        let raw = try await NetworkClient.fetch(components.url!, as: [WPPostContent].self)
        var result: [Int: ArticleEnrichment] = [:]
        for post in raw {
            result[post.id] = ArticleEnrichment(
                contentHTML: post.content.rendered,
                author: post.embedded?.authors?.first?.name,
                featuredImageURL: post.embedded?.media?.first?.sourceURL.flatMap { URL(string: $0) }
            )
        }
        return result
    }

    // MARK: - Notices

    static func fetchNotices() async throws -> [Notice] {
        var components = URLComponents(url: base.appendingPathComponent("sh_notice"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "20"),
            URLQueryItem(name: "_fields", value: "id,title,excerpt"),
            URLQueryItem(name: "orderby", value: "date"),
            URLQueryItem(name: "order", value: "desc"),
        ]
        let raw = try await NetworkClient.fetch(components.url!, as: [WPNotice].self)
        return raw.map { Notice(id: $0.id, title: $0.title.rendered.htmlDecoded, excerpt: $0.excerpt.rendered.htmlStripped) }
    }
}

// MARK: - Raw Codable types

private struct WPPost: Decodable {
    let id: Int
    let link: String
    let date: String
    let title: WPRendered
    let tags: [Int]
    let embedded: WPEmbedded?

    enum CodingKeys: String, CodingKey {
        case id, link, date, title, tags
        case embedded = "_embedded"
    }
}

private struct WPPostContent: Decodable {
    let id: Int
    let content: WPRendered
    let embedded: WPEmbedded?

    enum CodingKeys: String, CodingKey {
        case id, content
        case embedded = "_embedded"
    }
}

private struct WPRendered: Decodable {
    let rendered: String
}

private struct WPEmbedded: Decodable {
    let authors: [WPAuthor]?
    let media: [WPMedia]?

    enum CodingKeys: String, CodingKey {
        case authors = "author"
        case media = "wp:featuredmedia"
    }
}

private struct WPAuthor: Decodable { let name: String }
private struct WPMedia: Decodable {
    let sourceURL: String?
    enum CodingKeys: String, CodingKey { case sourceURL = "source_url" }
}

private struct WPNotice: Decodable {
    let id: Int
    let title: WPRendered
    let excerpt: WPRendered
}

struct ArticleEnrichment: Codable {
    let contentHTML: String
    let author: String?
    let featuredImageURL: URL?
}

// MARK: - Article init from raw

private extension Article {
    init?(from post: WPPost) {
        guard let link = URL(string: post.link) else { return nil }
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: post.date) ?? Date()
        self.init(
            id: post.id,
            title: post.title.rendered.htmlDecoded,
            link: link,
            published: date,
            tagIDs: post.tags,
            author: post.embedded?.authors?.first?.name,
            contentHTML: nil,
            featuredImageURL: post.embedded?.media?.first?.sourceURL.flatMap { URL(string: $0) }
        )
    }
}

// MARK: - String helpers

extension String {
    var htmlDecoded: String {
        guard let data = wrappedHTML.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
              )
        else {
            return self
        }
        return attributed.string
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var htmlStripped: String {
        guard let data = data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
              )
        else {
            return htmlDecoded
        }
        return attributed.string
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var wrappedHTML: String {
        "<span>\(self)</span>"
    }
}
