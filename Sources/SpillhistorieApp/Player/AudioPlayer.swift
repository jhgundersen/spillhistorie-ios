import Foundation
import AVFoundation
import MediaPlayer
import UIKit

enum PlayerState {
    case stopped, playing, paused, buffering
}

@MainActor
@Observable
final class AudioPlayer {
    static let shared = AudioPlayer()

    private(set) var state: PlayerState = .stopped
    private(set) var currentEpisode: PodcastEpisode?
    private(set) var currentPosition: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var chapters: [Chapter] = []

    private var player: AVPlayer?
    private var timeObserver: Any?
    private let resumeStore = ResumeStateStore()
    private let nowPlaying = NowPlayingManager()

    private init() {
        setupAudioSession()
        setupInterruptionObserver()
        nowPlaying.setup(player: self)
    }

    // MARK: - Public controls

    func play(_ episode: PodcastEpisode, from position: TimeInterval = 0) {
        stop(saveResume: false)
        currentEpisode = episode
        state = .buffering
        duration = TimeInterval(episode.durationSeconds)

        let item = AVPlayerItem(url: episode.audioURL)
        player = AVPlayer(playerItem: item)
        player?.seek(to: CMTime(seconds: position, preferredTimescale: 1000))
        player?.play()
        state = .playing
        currentPosition = position

        startPeriodicObserver()
        nowPlaying.update(episode: episode, position: position, duration: duration)
        loadChapters(for: episode)

        NotificationCenter.default.addObserver(
            self, selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime, object: item
        )
    }

    func togglePlayPause() {
        guard let player else { return }
        if state == .playing {
            player.pause()
            state = .paused
        } else {
            player.play()
            state = .playing
        }
        nowPlaying.update(episode: currentEpisode, position: currentPosition, duration: duration, isPlaying: state == .playing)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func seek(by delta: TimeInterval) {
        guard let player else { return }
        let newPos = max(0, currentPosition + delta)
        player.seek(to: CMTime(seconds: newPos, preferredTimescale: 1000))
        currentPosition = newPos
        nowPlaying.update(episode: currentEpisode, position: currentPosition, duration: duration, isPlaying: state == .playing)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    func seekToPosition(_ position: TimeInterval) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: position, preferredTimescale: 1000))
        currentPosition = position
        nowPlaying.update(episode: currentEpisode, position: currentPosition, duration: duration, isPlaying: state == .playing)
    }

    func stop(saveResume: Bool = true) {
        if saveResume, let episode = currentEpisode {
            let resume = ResumeState(
                audioURL: episode.audioURL,
                title: episode.title,
                series: episode.series,
                durationSeconds: duration,
                positionSeconds: currentPosition
            )
            if resume.isResumable {
                resumeStore.save(resume)
            } else {
                resumeStore.clear()
            }
        }
        removePeriodicObserver()
        player?.pause()
        player = nil
        state = .stopped
        currentEpisode = nil
        currentPosition = 0
        chapters = []
    }

    func loadSavedResume() -> ResumeState? {
        resumeStore.load()
    }

    // MARK: - Current chapter

    var currentChapterIndex: Int? {
        guard !chapters.isEmpty else { return nil }
        var idx = 0
        for (i, chapter) in chapters.enumerated() {
            if chapter.startTime <= currentPosition { idx = i } else { break }
        }
        return idx
    }

    // MARK: - Private

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification, object: nil
        )
    }

    @objc private nonisolated func handleInterruption(_ notification: Notification) {
        let userInfo = notification.userInfo
        Task { @MainActor [weak self] in
            guard let self,
                  let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            if type == .began {
                if self.state == .playing { self.player?.pause(); self.state = .paused }
            } else if type == .ended {
                if let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
                   AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                    self.player?.play(); self.state = .playing
                }
            }
        }
    }

    private func startPeriodicObserver() {
        removePeriodicObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentPosition = time.seconds
            // Update duration from actual item if available
            if let dur = self.player?.currentItem?.duration, dur.isValid, dur.seconds > 0 {
                self.duration = dur.seconds
            }
            self.nowPlaying.update(
                episode: self.currentEpisode,
                position: self.currentPosition,
                duration: self.duration,
                isPlaying: self.state == .playing
            )
            // Auto-save resume state periodically
            if let episode = self.currentEpisode {
                let resume = ResumeState(
                    audioURL: episode.audioURL,
                    title: episode.title,
                    series: episode.series,
                    durationSeconds: self.duration,
                    positionSeconds: self.currentPosition
                )
                if resume.isResumable { self.resumeStore.save(resume) }
            }
        }
    }

    private func removePeriodicObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    @objc private nonisolated func playerDidFinish() {
        Task { @MainActor [weak self] in
            self?.resumeStore.clear()
            self?.state = .stopped
            self?.currentPosition = 0
        }
    }

    private func loadChapters(for episode: PodcastEpisode) {
        guard let url = episode.chapterURL else { return }
        Task { @MainActor in
            self.chapters = await ChapterFetcher.fetch(from: url)
        }
    }
}
