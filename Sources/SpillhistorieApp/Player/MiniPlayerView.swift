import SwiftUI

struct MiniPlayerView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var showFullPlayer = false

    var body: some View {
        if let episode = player.currentEpisode {
            VStack(spacing: 0) {
                // Thin progress strip
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progressFraction)
                }
                .frame(height: 2)

                HStack(spacing: 16) {
                    // Artwork thumbnail
                    ArtworkView(url: episode.artworkURL, size: 40)

                    // Title + series
                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(episode.series)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Skip back
                    Button {
                        player.seek(by: -10)
                    } label: {
                        Image(systemName: "gobackward.10")
                            .imageScale(.large)
                    }

                    // Play/pause
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                            .imageScale(.large)
                            .frame(width: 28)
                    }

                    // Skip forward
                    Button {
                        player.seek(by: 30)
                    } label: {
                        Image(systemName: "goforward.30")
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
            .contentShape(Rectangle())
            .onTapGesture { showFullPlayer = true }
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerSheet()
                    .environment(player)
            }
        }
    }

    private var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(1, player.currentPosition / player.duration)
    }
}

struct ArtworkView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: size * 0.15)
            .fill(Color.accentColor.opacity(0.2))
            .overlay {
                Image(systemName: "waveform")
                    .foregroundStyle(Color.accentColor)
            }
    }
}
