import Foundation
import FeedKit

enum PodcastFeedParser {
    static func fetchAllEpisodes() async -> [PodcastEpisode] {
        await withTaskGroup(of: [PodcastEpisode].self) { group in
            for series in podcastSeries {
                group.addTask { await parseFeed(name: series.name, urlString: series.url) }
            }
            var all: [PodcastEpisode] = []
            for await episodes in group {
                all.append(contentsOf: episodes)
            }
            return all.sorted { $0.published > $1.published }
        }
    }

    private static func parseFeed(name: String, urlString: String) async -> [PodcastEpisode] {
        guard let url = URL(string: urlString) else { return [] }
        return await withCheckedContinuation { continuation in
            let parser = FeedParser(URL: url)
            parser.parseAsync { result in
                switch result {
                case .success(let feed):
                    let episodes = extractEpisodes(from: feed, seriesName: name)
                    continuation.resume(returning: episodes)
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private static func extractEpisodes(from feed: Feed, seriesName: String) -> [PodcastEpisode] {
        guard case .rss(let rssFeed) = feed, let items = rssFeed.items else { return [] }
        let feedArtwork = rssFeed.iTunes?.iTunesImage?.attributes?.href.flatMap { URL(string: $0) }

        return items.compactMap { item -> PodcastEpisode? in
            guard
                let title = item.title,
                let enclosure = item.enclosure,
                let audioURLString = enclosure.attributes?.url,
                let audioURL = URL(string: audioURLString)
            else { return nil }

            let duration = Int(item.iTunes?.iTunesDuration ?? 0)
            let published = item.pubDate ?? Date()
            let author = item.iTunes?.iTunesAuthor ?? item.author ?? seriesName
            let artwork = item.iTunes?.iTunesImage?.attributes?.href.flatMap { URL(string: $0) } ?? feedArtwork
            let summary = item.iTunes?.iTunesSummary ?? item.description

            // podcast:chapters is in the namespaced extensions — FeedKit exposes raw namespaced XML
            // Access via DublinCore or raw extensions dict (FeedKit v9 doesn't parse podcast: ns natively)
            let chapterURL: URL? = nil  // populated in ChapterFetcher when needed

            return PodcastEpisode(
                id: audioURLString,
                title: title.htmlDecoded,
                audioURL: audioURL,
                durationSeconds: duration,
                series: seriesName,
                author: author.htmlDecoded,
                published: published,
                summary: summary?.htmlStripped,
                chapterURL: chapterURL,
                artworkURL: artwork
            )
        }
    }

}
