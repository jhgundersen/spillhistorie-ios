import SwiftUI

@main
struct SpillhistorieApp: App {
    @State private var articleStore = ArticleStore()
    @State private var podcastStore = PodcastStore()
    @State private var audioPlayer = AudioPlayer.shared
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(articleStore)
                .environment(podcastStore)
                .environment(audioPlayer)
                .environment(appSettings)
                .preferredColorScheme(appSettings.preferredColorScheme)
        }
    }
}
