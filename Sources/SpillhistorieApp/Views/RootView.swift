import SwiftUI

struct RootView: View {
    @Environment(ArticleStore.self) private var articleStore
    @Environment(PodcastStore.self) private var podcastStore
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var selectedCategory: ArticleCategory = ArticleCategory.all[0]
    @State private var showPodcasts = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCategory: $selectedCategory,
                showPodcasts: $showPodcasts
            )
        } content: {
            if showPodcasts {
                PodcastListView()
            } else {
                ArticleListView(category: selectedCategory)
            }
        } detail: {
            ContentUnavailableView(
                "Velg en artikkel",
                systemImage: "doc.text",
                description: Text("Velg en artikkel fra listen til venstre.")
            )
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
