import Foundation

struct PodcastCacheStore {
    private let url: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = root.appendingPathComponent("PodcastCache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("episodes.json")
    }

    func loadEpisodes() -> [PodcastEpisode]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode([PodcastEpisode].self, from: data)
    }

    func saveEpisodes(_ episodes: [PodcastEpisode]) {
        guard let data = try? encoder.encode(episodes) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
