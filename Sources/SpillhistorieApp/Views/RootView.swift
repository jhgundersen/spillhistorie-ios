import SwiftUI

struct RootView: View {
    @Environment(ArticleStore.self) private var articleStore
    @Environment(PodcastStore.self) private var podcastStore
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(AppSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedCategory: ArticleCategory = ArticleCategory.all[0]
    @State private var showPodcasts = false
    @State private var showSettings = false
    @State private var selectedArticle: Article?
    @State private var selectedEpisode: PodcastEpisode?

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                CompactRootView(selectedArticle: $selectedArticle, selectedEpisode: $selectedEpisode)
            } else {
                NavigationSplitView {
                    SidebarView(
                        selectedCategory: $selectedCategory,
                        showPodcasts: $showPodcasts,
                        showSettings: $showSettings
                    )
                } content: {
                    if showSettings {
                        SettingsPromptView()
                    } else if showPodcasts {
                        PodcastListView(selectedEpisode: $selectedEpisode)
                    } else {
                        ArticleListView(category: selectedCategory, selectedArticle: $selectedArticle)
                    }
                } detail: {
                    if showSettings {
                        SettingsView()
                    } else if showPodcasts, let selectedEpisode {
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
            }
        }
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
            showSettings = false
            showPodcasts = false
            Task { await articleStore.loadCategory(newCat) }
        }
    }
}

private struct CompactRootView: View {
    @Binding var selectedArticle: Article?
    @Binding var selectedEpisode: PodcastEpisode?

    var body: some View {
        NavigationStack {
            List {
                Section("Artikler") {
                    ForEach(ArticleCategory.all) { category in
                        NavigationLink(value: CompactRoute.category(category)) {
                            Label(category.name, systemImage: categoryIcon(category))
                        }
                    }
                }

                Section("Podkast") {
                    NavigationLink(value: CompactRoute.podcasts) {
                        Label("Alle episoder", systemImage: "waveform")
                    }
                }

                Section("App") {
                    NavigationLink(value: CompactRoute.settings) {
                        Label("Innstillinger", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Spillhistorie")
            .navigationDestination(for: CompactRoute.self) { route in
                switch route {
                case .category(let category):
                    ArticleListView(category: category, selectedArticle: $selectedArticle)
                case .podcasts:
                    PodcastListView(selectedEpisode: $selectedEpisode)
                case .settings:
                    SettingsView()
                }
            }
        }
    }

    private func categoryIcon(_ cat: ArticleCategory) -> String {
        switch cat.id {
        case "framside": return "house"
        case "nyespill": return "gamecontroller"
        case "retro": return "clock.arrow.circlepath"
        case "indie": return "sparkles"
        case "inntrykk": return "eye"
        case "features": return "star"
        case "quiz": return "questionmark.circle"
        default: return "doc.text"
        }
    }
}

private enum CompactRoute: Hashable {
    case category(ArticleCategory)
    case podcasts
    case settings
}

private struct SettingsPromptView: View {
    var body: some View {
        ContentUnavailableView(
            "Innstillinger",
            systemImage: "gearshape",
            description: Text("Juster utseende, skrifttype og podkastcache i panelet til hoyre.")
        )
    }
}

private struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PodcastStore.self) private var podcastStore
    @State private var clearedPodcastCache = false

    var body: some View {
        Form {
            Section("Utseende") {
                Toggle("Dark mode", isOn: Bindable(settings).darkModeEnabled)

                Picker("Skrifttype", selection: Bindable(settings).fontStyle) {
                    ForEach(AppSettings.FontStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.inline)

                Text("Skrifttypen brukes bare i artikkelvisningen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Podkast") {
                Button(role: .destructive) {
                    podcastStore.clearCache()
                    clearedPodcastCache = true
                } label: {
                    Label("Slett podkastcache", systemImage: "trash")
                }

                if clearedPodcastCache {
                    Text("Podkastcache og nedlastinger slettet. Episodene kan lastes ned pa nytt senere.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .navigationTitle("Innstillinger")
    }
}

struct PodcastEpisodeDetailView: View {
    let episode: PodcastEpisode

    @Environment(AudioPlayer.self) private var player
    @Environment(PodcastStore.self) private var podcastStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metadata
                playbackStatus
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
        Group {
            if horizontalSizeClass == .compact {
                VStack(alignment: .leading, spacing: 16) {
                    ArtworkView(url: episode.artworkURL, size: 140)
                    episodeTextHeader(titleFont: .title2)
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    ArtworkView(url: episode.artworkURL, size: 180)
                    episodeTextHeader(titleFont: .largeTitle)
                }
            }
        }
    }

    private func episodeTextHeader(titleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(episode.title)
                .font(titleFont)
                .fontWeight(.bold)

            Text(episode.series)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(episode.author)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        let stack = horizontalSizeClass == .compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return stack {
            Button {
                if player.currentEpisode?.id == episode.id {
                    player.togglePlayPause()
                } else {
                    player.play(episode, using: podcastStore.playbackURL(for: episode))
                }
            } label: {
                Image(systemName: player.currentEpisode?.id == episode.id && player.state == .playing ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(player.currentEpisode?.id == episode.id && player.state == .playing ? "Pause" : "Spill av")

            Button {
                player.play(episode, using: podcastStore.playbackURL(for: episode), from: 0)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Fra starten")

            ShareLink(item: episode.audioURL) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Del episode")

            if podcastStore.isDownloaded(episode) {
                Button(role: .destructive) {
                    podcastStore.deleteDownload(for: episode)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Slett nedlasting")
            } else {
                Button {
                    Task { await podcastStore.downloadEpisode(episode) }
                } label: {
                    Image(systemName: podcastStore.isDownloading(episode) ? "arrow.down.circle.dotted" : "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .disabled(podcastStore.isDownloading(episode))
                .accessibilityLabel(podcastStore.isDownloading(episode) ? "Laster ned" : "Last ned")
            }
        }
    }

    @ViewBuilder
    private var playbackStatus: some View {
        if player.currentEpisode?.id == episode.id {
            VStack(alignment: .leading, spacing: 6) {
                Label(player.state == .playing ? "Spiller na" : "Klar til avspilling", systemImage: player.state == .playing ? "waveform" : "pause.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if player.duration > 0 {
                    ProgressView(value: min(max(player.currentPosition / player.duration, 0), 1))
                    Text("\(formatTimestamp(player.currentPosition)) av \(formatTimestamp(player.duration))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Label(podcastStore.isDownloaded(episode) ? "Nedlastet for offline lytting" : (podcastStore.isDownloading(episode) ? "Laster ned episode" : "Ikke lastet ned"), systemImage: podcastStore.isDownloaded(episode) ? "checkmark.circle.fill" : (podcastStore.isDownloading(episode) ? "arrow.down.circle.dotted" : "icloud.and.arrow.down"))
                    .font(.caption)
                    .foregroundStyle(podcastStore.isDownloaded(episode) ? .green : .secondary)
            }
        } else {
            Label(podcastStore.isDownloaded(episode) ? "Nedlastet for offline lytting" : (podcastStore.isDownloading(episode) ? "Laster ned episode" : "Ikke lastet ned"), systemImage: podcastStore.isDownloaded(episode) ? "checkmark.circle.fill" : (podcastStore.isDownloading(episode) ? "arrow.down.circle.dotted" : "icloud.and.arrow.down"))
                .font(.subheadline)
                .foregroundStyle(podcastStore.isDownloaded(episode) ? .green : .secondary)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h) t \(m) min" }
        return "\(m) min"
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
