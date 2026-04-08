import AVKit
import SwiftUI

struct ArticleView: View {
    let blocks: [ArticleBlock]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                ArticleBlockView(block: block)
                    .padding(.bottom, blockBottomPadding(block))
            }
        }
    }

    private func blockBottomPadding(_ block: ArticleBlock) -> CGFloat {
        switch block {
        case .heading: return 8
        case .paragraph: return 14
        case .image, .audio, .video, .embed: return 16
        case .blockquote: return 16
        case .codeBlock: return 16
        case .unorderedList, .orderedList: return 14
        case .divider: return 24
        }
    }
}

struct ArticleBlockView: View {
    let block: ArticleBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            HeadingBlockView(level: level, text: text)
        case .paragraph(let inlines):
            ParagraphBlockView(inlines: inlines)
        case .image(let src, let alt, let caption):
            ImageBlockView(src: src, alt: alt, caption: caption)
        case .audio(let src):
            AudioBlockView(src: src)
        case .video(let src, let poster):
            VideoBlockView(src: src, poster: poster)
        case .embed(let src, let title):
            EmbedBlockView(src: src, title: title)
        case .blockquote(let inner):
            BlockquoteBlockView(blocks: inner)
        case .codeBlock(let text):
            CodeBlockView(text: text)
        case .unorderedList(let items):
            ListBlockView(items: items, ordered: false)
        case .orderedList(let items):
            ListBlockView(items: items, ordered: true)
        case .divider:
            Divider()
                .padding(.vertical, 8)
        }
    }
}

private struct AudioBlockView: View {
    let src: URL
    @State private var player = AVPlayer()
    @State private var isPlaying = false
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var observer: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.14))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { duration > 0 ? currentTime : 0 },
                            set: { newValue in
                                currentTime = newValue
                            }
                        ),
                        in: 0...(duration > 0 ? duration : 1),
                        onEditingChanged: { editing in
                            if !editing {
                                let time = CMTime(seconds: currentTime, preferredTimescale: 600)
                                player.seek(to: time)
                            }
                        }
                    )

                    HStack {
                        Text(formatTime(currentTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: src) {
            await configurePlayer()
        }
        .onDisappear {
            if let observer {
                player.removeTimeObserver(observer)
                self.observer = nil
            }
            player.pause()
        }
    }

    private func configurePlayer() async {
        if let observer {
            player.removeTimeObserver(observer)
            self.observer = nil
        }

        let item = AVPlayerItem(url: src)
        player.replaceCurrentItem(with: item)
        isPlaying = false
        currentTime = 0
        if let loadedDuration = try? await item.asset.load(.duration) {
            duration = loadedDuration.seconds.isFinite ? loadedDuration.seconds : 0
        } else {
            duration = 0
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds.isFinite ? time.seconds : 0
            if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite {
                duration = itemDuration
            }
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func formatTime(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        let total = Int(value)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct VideoBlockView: View {
    let src: URL
    let poster: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let poster {
                AsyncImage(url: poster) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            MediaPlayerContainer(url: src, height: 220)
        }
    }
}

private struct MediaPlayerContainer: View {
    let url: URL
    let height: CGFloat
    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .task(id: url) {
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
            }
            .onDisappear {
                player.pause()
            }
    }
}

private struct EmbedBlockView: View {
    let src: URL
    let title: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                openURL(watchURL)
            } label: {
                ZStack {
                    thumbnail

                    Circle()
                        .fill(.black.opacity(0.72))
                        .frame(width: 62, height: 62)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .offset(x: 2)
                        }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Apner videoen i YouTube")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var watchURL: URL {
        if let videoID {
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)") ?? src
        }
        return src
    }

    private var videoID: String? {
        let pathComponents = src.pathComponents
        if let embedIndex = pathComponents.firstIndex(of: "embed"), pathComponents.indices.contains(embedIndex + 1) {
            return pathComponents[embedIndex + 1]
        }
        if let host = URLComponents(url: src, resolvingAgainstBaseURL: false)?.host,
           host.contains("youtu.be") {
            return src.pathComponents.dropFirst().first
        }
        return URLComponents(url: src, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let videoID,
           let thumbnailURL = URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg") {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color.red.opacity(0.85), Color.black.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
