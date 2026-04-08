import Foundation

struct PodcastDownloadStore {
    private let downloadsDirectory: URL

    init(fileManager: FileManager = .default) {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        downloadsDirectory = root.appendingPathComponent("PodcastDownloads", isDirectory: true)
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }

    func localFileURL(for episode: PodcastEpisode) -> URL {
        let encodedID = Data(episode.id.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        let ext = episode.audioURL.pathExtension.isEmpty ? "mp3" : episode.audioURL.pathExtension
        return downloadsDirectory.appendingPathComponent("\(encodedID).\(ext)")
    }

    func downloadedFileURL(for episode: PodcastEpisode) -> URL? {
        let url = localFileURL(for: episode)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func download(_ episode: PodcastEpisode) async throws -> URL {
        let destination = localFileURL(for: episode)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        let (temporaryURL, _) = try await URLSession.shared.download(from: episode.audioURL)
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    func deleteDownload(for episode: PodcastEpisode) {
        let url = localFileURL(for: episode)
        try? FileManager.default.removeItem(at: url)
    }

    func clearAllDownloads() {
        let fileManager = FileManager.default
        let urls = (try? fileManager.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in urls {
            try? fileManager.removeItem(at: url)
        }
    }
}
