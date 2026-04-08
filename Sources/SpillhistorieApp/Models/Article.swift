import Foundation

struct Article: Identifiable, Hashable, Codable {
    let id: Int
    let title: String
    let link: URL
    let published: Date
    let tagIDs: [Int]

    // Phase 2 enrichment — nil until background fetch completes
    var author: String?
    var contentHTML: String?
    var featuredImageURL: URL?

    var isQuiz: Bool { tagIDs.contains(300) || tagIDs.contains(6750) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Article, rhs: Article) -> Bool { lhs.id == rhs.id }
}

struct ArticleCategory: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let wpCategoryID: Int?
    let tagIDs: [Int]

    static let all: [ArticleCategory] = [
        ArticleCategory(id: "framside",  name: "Framside",   wpCategoryID: nil,  tagIDs: []),
        ArticleCategory(id: "nyespill",  name: "Nye spill",  wpCategoryID: 3,    tagIDs: []),
        ArticleCategory(id: "retro",     name: "Retro",      wpCategoryID: 4,    tagIDs: []),
        ArticleCategory(id: "indie",     name: "Indie",      wpCategoryID: 1044, tagIDs: []),
        ArticleCategory(id: "inntrykk", name: "Inntrykk",   wpCategoryID: 1038, tagIDs: []),
        ArticleCategory(id: "features",  name: "Features",   wpCategoryID: 2892, tagIDs: []),
        ArticleCategory(id: "quiz",      name: "Quiz",       wpCategoryID: nil,  tagIDs: [300, 6750]),
    ]
}
