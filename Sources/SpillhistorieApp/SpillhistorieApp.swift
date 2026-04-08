import SwiftUI

@main
struct SpillhistorieApp: App {
    @State private var articleStore = ArticleStore()
    @State private var podcastStore = PodcastStore()
    @State private var audioPlayer = AudioPlayer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(articleStore)
                .environment(podcastStore)
                .environment(audioPlayer)
        }
    }
}
