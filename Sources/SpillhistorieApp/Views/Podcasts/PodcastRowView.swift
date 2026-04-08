import SwiftUI

struct PodcastRowView: View {
    let episode: PodcastEpisode
    let onPlay: () -> Void
    @Environment(AudioPlayer.self) private var player
    @Environment(PodcastStore.self) private var store

    var isPlaying: Bool {
        player.currentEpisode?.id == episode.id && player.state == .playing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                ArtworkView(url: episode.artworkURL, size: 56)
                if isPlaying {
                    RoundedRectangle(cornerRadius: 56 * 0.15)
                        .fill(.black.opacity(0.4))
                        .frame(width: 56, height: 56)
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(episode.series)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(episode.published, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if episode.durationSeconds > 0 {
                    HStack(spacing: 6) {
                        Text(formatDuration(episode.durationSeconds))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if store.isDownloaded(episode) {
                            Label("Nedlastet", systemImage: "arrow.down.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else if store.isDownloading(episode) {
                            Label("Laster ned", systemImage: "arrow.down.circle.dotted")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onPlay) {
                Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h) t \(m) min" }
        return "\(m) min"
    }
}
