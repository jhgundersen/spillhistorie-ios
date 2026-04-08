import Foundation

@Observable
final class PodcastStore {
    var episodes: [PodcastEpisode] = []
    var isLoading = false
    var error: String?
    var selectedSeries: String? = nil  // nil = all

    var filtered: [PodcastEpisode] {
        guard let series = selectedSeries else { return episodes }
        return episodes.filter { $0.series == series }
    }

    var allSeries: [String] {
        podcastSeries.map { $0.name }
    }

    func load() async {
        guard episodes.isEmpty else { return }
        isLoading = true
        episodes = await PodcastFeedParser.fetchAllEpisodes()
        isLoading = false
    }

    func refresh() async {
        isLoading = true
        episodes = await PodcastFeedParser.fetchAllEpisodes()
        isLoading = false
    }
}
