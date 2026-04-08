import SwiftUI

struct RootView: View {
    @Environment(ArticleStore.self) private var articleStore
    @Environment(PodcastStore.self) private var podcastStore
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var selectedCategory: ArticleCategory = ArticleCategory.all[0]
    @State private var showPodcasts = false
    @State private var resumeEpisode: PodcastEpisode?
    @State private var showResumeAlert = false

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
            await articleStore.loadNotices()
            // Check for resume state
            if let resume = audioPlayer.loadSavedResume() {
                // Find matching episode after podcasts load
                await podcastStore.load()
                if let ep = podcastStore.episodes.first(where: { $0.audioURL.absoluteString == resume.audioURL.absoluteString }) {
                    resumeEpisode = ep
                    showResumeAlert = true
                }
            } else {
                Task { await podcastStore.load() }
            }
        }
        .onChange(of: selectedCategory) { _, newCat in
            showPodcasts = false
            Task { await articleStore.loadCategory(newCat) }
        }
        .alert("Fortsett avspilling?", isPresented: $showResumeAlert, presenting: resumeEpisode) { ep in
            Button("Fortsett") { audioPlayer.play(ep, from: audioPlayer.loadSavedResume()?.positionSeconds ?? 0) }
            Button("Avbryt", role: .cancel) { ResumeStateStore().clear() }
        } message: { ep in
            Text("Vil du fortsette å lytte til \"\(ep.title)\"?")
        }
    }
}
