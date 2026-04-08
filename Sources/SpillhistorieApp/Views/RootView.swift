import SwiftUI

struct RootView: View {
    @Environment(ArticleStore.self) private var articleStore
    @Environment(PodcastStore.self) private var podcastStore
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var selectedCategory: ArticleCategory = ArticleCategory.all[0]
    @State private var showPodcasts = false
    @State private var selectedArticle: Article?
    @State private var selectedEpisode: PodcastEpisode?

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCategory: $selectedCategory,
                showPodcasts: $showPodcasts
            )
        } content: {
            if showPodcasts {
                PodcastListView(selectedEpisode: $selectedEpisode)
            } else {
                ArticleListView(category: selectedCategory, selectedArticle: $selectedArticle)
            }
        } detail: {
            if showPodcasts, let selectedEpisode {
                PodcastEpisodeDetailView(episode: selectedEpisode)
            } else if let selectedArticle {
                ArticleDetailView(articleID: selectedArticle.id, fallbackArticle: selectedArticle)
            } else {
                ContentUnavailableView(
                    showPodcasts ? "Velg en episode" : "Velg en artikkel",
                    systemImage: showPodcasts ? "mic" : "doc.text",
                    description: Text(showPodcasts ? "Velg en episode fra listen til venstre." : "Velg en artikkel fra listen til venstre.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .safeAreaInset(edge: .bottom) {
            MiniPlayerView()
        }
        .task {
            await articleStore.loadCategory(selectedCategory)
            await podcastStore.load()
            if let resume = audioPlayer.loadSavedResume() {
                if let ep = podcastStore.episodes.first(where: { $0.audioURL.absoluteString == resume.audioURL.absoluteString }) {
                    audioPlayer.restore(ep, from: resume.positionSeconds)
                }
            }
        }
        .onChange(of: selectedCategory) { _, newCat in
            showPodcasts = false
            Task { await articleStore.loadCategory(newCat) }
        }
    }
}

private struct PodcastEpisodeDetailView: View {
    let episode: PodcastEpisode

    @Environment(AudioPlayer.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metadata
                actionRow
                if let summary = episode.summary, !summary.isEmpty {
                    Divider()
                    Text(summary)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle(episode.series)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            ArtworkView(url: episode.artworkURL, size: 180)

            VStack(alignment: .leading, spacing: 12) {
                Text(episode.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(episode.series)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(episode.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 10) {
            Label(episode.published.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            if episode.durationSeconds > 0 {
                Label(formatDuration(episode.durationSeconds), systemImage: "clock")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                if player.currentEpisode?.id == episode.id {
                    player.togglePlayPause()
                } else {
                    player.play(episode)
                }
            } label: {
                Label(player.currentEpisode?.id == episode.id && player.state == .playing ? "Pause" : "Spill av", systemImage: player.currentEpisode?.id == episode.id && player.state == .playing ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)

            Button {
                player.play(episode, from: 0)
            } label: {
                Label("Fra starten", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)

            ShareLink(item: episode.audioURL) {
                Label("Del episode", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h) t \(m) min" }
        return "\(m) min"
    }
}
