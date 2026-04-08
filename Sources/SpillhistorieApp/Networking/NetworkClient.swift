import Foundation

enum NetworkClient {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 50_000_000,   // 50 MB
            diskCapacity: 500_000_000     // 500 MB
        )
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["User-Agent": "SpillhistorieApp/1.0 (iPad)"]
        return URLSession(configuration: config)
    }()

    static func fetch<T: Decodable>(_ url: URL, as type: T.Type = T.self) async throws -> T {
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    static func fetchData(from url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}
