import Foundation
import MediaPlayer
import AVFoundation
import UIKit

@MainActor
final class NowPlayingManager {
    private weak var audioPlayer: AudioPlayer?
    private var lastArtworkURL: URL?

    func setup(player: AudioPlayer) {
        self.audioPlayer = player
        setupRemoteCommands()
    }

    func update(episode: PodcastEpisode?, position: TimeInterval, duration: TimeInterval, isPlaying: Bool = true) {
        guard let episode else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: episode.series,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : Double(episode.durationSeconds),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        // Load artwork only if URL changed
        if let artURL = episode.artworkURL, artURL != lastArtworkURL {
            lastArtworkURL = artURL
            Task {
                guard let data = try? await NetworkClient.fetchData(from: artURL),
                      let uiImage = UIImage(data: data)
                else { return }
                let artwork = MPMediaItemArtwork(boundsSize: uiImage.size) { _ in uiImage }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.audioPlayer?.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.audioPlayer?.togglePlayPause() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.audioPlayer?.seek(by: 30) }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.audioPlayer?.seek(by: -10) }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in self?.audioPlayer?.seekToPosition(e.positionTime) }
            return .success
        }
    }
}
