import Foundation

enum ChapterFetcher {
    private struct Response: Decodable {
        struct Item: Decodable {
            let startTime: Double
            let title: String
        }
        let chapters: [Item]
    }

    static func fetch(from url: URL) async -> [Chapter] {
        guard let data = try? await NetworkClient.fetchData(from: url),
              let response = try? JSONDecoder().decode(Response.self, from: data)
        else { return [] }
        return response.chapters.map { Chapter(id: UUID(), startTime: $0.startTime, title: $0.title) }
    }
}
