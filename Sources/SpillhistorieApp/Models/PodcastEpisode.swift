import Foundation

struct PodcastEpisode: Identifiable, Hashable, Codable {
    let id: String          // audioURL string used as stable ID
    let title: String
    let audioURL: URL
    let durationSeconds: Int
    let series: String
    let author: String
    let published: Date
    let summary: String?
    let chapterURL: URL?
    let artworkURL: URL?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PodcastEpisode, rhs: PodcastEpisode) -> Bool { lhs.id == rhs.id }
}

struct Chapter: Identifiable, Hashable {
    let id: UUID
    let startTime: TimeInterval
    let title: String
}

let podcastSeries: [(name: String, url: String)] = [
    ("Diskettkameratene", "https://feeds.transistor.fm/diskettkameratene"),
    ("cd SPILL",          "https://feed.podbean.com/cdspill/feed.xml"),
    ("Spæll",             "https://feed.podbean.com/spaell/feed.xml"),
    ("Pappskaller",       "https://anchor.fm/s/10b427ba4/podcast/rss"),
]
