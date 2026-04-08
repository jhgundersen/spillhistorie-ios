import Foundation

@MainActor
@Observable
final class PodcastStore {
    var episodes: [PodcastEpisode] = []
    var isLoading = false
    var error: String?
    var selectedSeries: String? = nil  // nil = all
    private let cacheStore = PodcastCacheStore()
    private let downloadStore = PodcastDownloadStore()
    var downloadedEpisodeIDs: Set<String> = []
    var downloadingEpisodeIDs: Set<String> = []

    var filtered: [PodcastEpisode] {
        guard let series = selectedSeries else { return episodes }
        return episodes.filter { $0.series == series }
    }

    var allSeries: [String] {
        podcastSeries.map { $0.name }
    }

    func load() async {
        if episodes.isEmpty, let cached = cacheStore.loadEpisodes(), !cached.isEmpty {
            episodes = cached
            refreshDownloadedState()
        }
        guard episodes.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        let fresh = await PodcastFeedParser.fetchAllEpisodes()
        if !fresh.isEmpty {
            episodes = fresh
            cacheStore.saveEpisodes(fresh)
            refreshDownloadedState()
            error = nil
        } else if episodes.isEmpty {
            error = "Kunne ikke laste podkastene."
        }
        isLoading = false
    }

    func clearCache() {
        cacheStore.clear()
        downloadStore.clearAllDownloads()
        downloadedEpisodeIDs.removeAll()
        downloadingEpisodeIDs.removeAll()
        URLCache.shared.removeAllCachedResponses()
        NetworkClient.session.configuration.urlCache?.removeAllCachedResponses()
    }

    func isDownloaded(_ episode: PodcastEpisode) -> Bool {
        downloadedEpisodeIDs.contains(episode.id)
    }

    func isDownloading(_ episode: PodcastEpisode) -> Bool {
        downloadingEpisodeIDs.contains(episode.id)
    }

    func playbackURL(for episode: PodcastEpisode) -> URL? {
        downloadStore.downloadedFileURL(for: episode)
    }

    func downloadEpisode(_ episode: PodcastEpisode) async {
        guard !isDownloaded(episode), !isDownloading(episode) else { return }
        downloadingEpisodeIDs.insert(episode.id)
        defer { downloadingEpisodeIDs.remove(episode.id) }

        do {
            _ = try await downloadStore.download(episode)
            downloadedEpisodeIDs.insert(episode.id)
        } catch {
            self.error = "Kunne ikke laste ned episoden."
        }
    }

    func deleteDownload(for episode: PodcastEpisode) {
        downloadStore.deleteDownload(for: episode)
        downloadedEpisodeIDs.remove(episode.id)
    }

    private func refreshDownloadedState() {
        downloadedEpisodeIDs = Set(episodes.compactMap { episode in
            downloadStore.downloadedFileURL(for: episode) != nil ? episode.id : nil
        })
    }
}
