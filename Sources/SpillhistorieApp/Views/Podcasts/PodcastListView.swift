import SwiftUI

struct PodcastListView: View {
    @Environment(PodcastStore.self) private var store
    @Environment(AudioPlayer.self) private var player
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedEpisode: PodcastEpisode?
    @State private var searchText = ""

    var filtered: [PodcastEpisode] {
        let base = store.filtered
        if searchText.isEmpty { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.series.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if store.isLoading && store.episodes.isEmpty {
                ProgressView("Laster episoder…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if horizontalSizeClass == .compact {
                    List(filtered) { episode in
                        NavigationLink(value: episode.id) {
                            PodcastRowView(episode: episode) {
                                playEpisode(episode)
                            }
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            selectedEpisode = episode
                        })
                        .swipeActions(edge: .trailing) {
                            episodeActions(episode)
                        }
                        .contextMenu {
                            episodeContextMenu(episode)
                        }
                    }
                    .navigationDestination(for: String.self) { episodeID in
                        if let episode = store.episodes.first(where: { $0.id == episodeID }) ?? selectedEpisode {
                            PodcastEpisodeDetailView(episode: episode)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await store.refresh() }
                } else {
                    List(filtered, selection: selectedEpisodeID) { episode in
                        PodcastRowView(episode: episode) {
                            playEpisode(episode)
                        }
                        .tag(episode.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEpisode = episode
                        }
                        .swipeActions(edge: .trailing) {
                            episodeActions(episode)
                        }
                        .contextMenu {
                            episodeContextMenu(episode)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await store.refresh() }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Søk i episoder")
        .navigationTitle("Podkast")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                seriesPicker
            }
        }
        .task {
            await store.load()
        }
    }

    private var seriesPicker: some View {
        Menu {
            Button("Alle") { store.selectedSeries = nil }
            ForEach(store.allSeries, id: \.self) { series in
                Button(series) { store.selectedSeries = series }
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.selectedSeries ?? "Alle")
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }

    private var selectedEpisodeID: Binding<String?> {
        Binding(
            get: { selectedEpisode?.id },
            set: { newValue in
                guard let newValue else {
                    selectedEpisode = nil
                    return
                }
                selectedEpisode = filtered.first(where: { $0.id == newValue }) ?? store.episodes.first(where: { $0.id == newValue }) ?? selectedEpisode
            }
        )
    }

    private func playEpisode(_ episode: PodcastEpisode) {
        if player.currentEpisode?.id == episode.id {
            player.togglePlayPause()
        } else {
            player.play(episode, using: store.playbackURL(for: episode))
        }
    }

    @ViewBuilder
    private func episodeActions(_ episode: PodcastEpisode) -> some View {
        if store.isDownloaded(episode) {
            Button(role: .destructive) {
                store.deleteDownload(for: episode)
            } label: {
                Label("Slett", systemImage: "trash")
            }
        } else {
            Button {
                Task { await store.downloadEpisode(episode) }
            } label: {
                Label("Last ned", systemImage: "arrow.down.circle")
            }
            .tint(.blue)
        }

        Button {
            player.play(episode, using: store.playbackURL(for: episode), from: 0)
        } label: {
            Label("Spill av", systemImage: "play.fill")
        }
        .tint(.accentColor)
    }

    @ViewBuilder
    private func episodeContextMenu(_ episode: PodcastEpisode) -> some View {
        Button("Spill av", systemImage: "play.fill") {
            player.play(episode, using: store.playbackURL(for: episode))
        }
        Button("Spill fra starten", systemImage: "arrow.counterclockwise") {
            player.play(episode, using: store.playbackURL(for: episode), from: 0)
        }
        if store.isDownloaded(episode) {
            Button("Slett nedlasting", systemImage: "trash", role: .destructive) {
                store.deleteDownload(for: episode)
            }
        } else {
            Button("Last ned", systemImage: "arrow.down.circle") {
                Task { await store.downloadEpisode(episode) }
            }
        }
        ShareLink(item: episode.audioURL) {
            Label("Del episode", systemImage: "square.and.arrow.up")
        }
    }
}
