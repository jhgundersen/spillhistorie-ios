import SwiftUI

struct FullPlayerSheet: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Large artwork
                    if let episode = player.currentEpisode {
                        ArtworkView(url: episode.artworkURL, size: 220)
                            .shadow(radius: 8)

                        // Title + series
                        VStack(spacing: 4) {
                            Text(episode.title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                            Text(episode.series)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        // Scrubber
                        scrubberSection

                        // Controls
                        controlsSection
                            .padding(.horizontal, 32)

                        // Chapters
                        if !player.chapters.isEmpty {
                            chaptersSection
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
            .navigationTitle("Nå spiller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { dismiss() }
                }
            }
        }
    }

    // MARK: - Scrubber

    private var scrubberSection: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                // Chapter tick marks
                if player.duration > 0 {
                    GeometryReader { geo in
                        ForEach(player.chapters) { chapter in
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.5))
                                .frame(width: 2, height: 10)
                                .offset(x: geo.size.width * (chapter.startTime / player.duration) - 1, y: 5)
                        }
                    }
                    .frame(height: 20)
                }
                Slider(
                    value: Binding(
                        get: { isDraggingSlider ? sliderValue : (player.duration > 0 ? player.currentPosition / player.duration : 0) },
                        set: { sliderValue = $0 }
                    ),
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            player.seekToPosition(sliderValue * player.duration)
                        }
                    }
                )
                .accentColor(.primary)
            }
            .padding(.horizontal)

            HStack {
                Text(formatTime(player.currentPosition))
                Spacer()
                if let name = currentChapterName {
                    Text(name)
                        .lineLimit(1)
                }
                Spacer()
                Text("-" + formatTime(max(0, player.duration - player.currentPosition)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: 40) {
            Button { player.seek(by: -10) } label: {
                Image(systemName: "gobackward.10")
                    .font(.title)
            }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 70))
            }
            Button { player.seek(by: 30) } label: {
                Image(systemName: "goforward.30")
                    .font(.title)
            }
        }
        .foregroundStyle(Color.primary)
    }

    // MARK: - Chapters

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kapitler")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 8)

            ForEach(player.chapters) { chapter in
                Button {
                    player.seekToPosition(chapter.startTime)
                } label: {
                    HStack {
                        if player.currentChapterIndex.map({ player.chapters[$0].id == chapter.id }) == true {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 16)
                        } else {
                            Text(formatTime(chapter.startTime))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)
                        }
                        Text(chapter.title)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(
                        player.currentChapterIndex.map({ player.chapters[$0].id == chapter.id }) == true
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var currentChapterName: String? {
        guard let idx = player.currentChapterIndex else { return nil }
        return player.chapters[idx].title
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
        }
    }
}
