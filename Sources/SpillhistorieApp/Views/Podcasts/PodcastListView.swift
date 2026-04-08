import SwiftUI

struct PodcastListView: View {
    @Environment(PodcastStore.self) private var store
    @Environment(AudioPlayer.self) private var player
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
                List(filtered, selection: selectedEpisodeID) { episode in
                    PodcastRowView(episode: episode) {
                        if player.currentEpisode?.id == episode.id {
                            player.togglePlayPause()
                        } else {
                            player.play(episode)
                        }
                    }
                    .tag(episode.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEpisode = episode
                    }
                        .swipeActions(edge: .trailing) {
                            Button {
                                player.play(episode, from: 0)
                            } label: {
                                Label("Spill av", systemImage: "play.fill")
                            }
                            .tint(.accentColor)
                        }
                        .contextMenu {
                            Button("Spill av", systemImage: "play.fill") {
                                player.play(episode)
                            }
                            Button("Spill fra starten", systemImage: "arrow.counterclockwise") {
                                player.play(episode, from: 0)
                            }
                            ShareLink(item: episode.audioURL) {
                                Label("Del episode", systemImage: "square.and.arrow.up")
                            }
                        }
                }
                .listStyle(.plain)
                .refreshable { await store.refresh() }
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
}
