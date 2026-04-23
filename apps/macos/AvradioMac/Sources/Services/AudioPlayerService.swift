import AVFoundation
import Foundation

@MainActor
final class AudioPlayerService: ObservableObject {
    enum PlaybackState: Equatable {
        case idle
        case loading
        case playing
        case paused
        case failed(String)
    }

    @Published private(set) var currentStation: Station?
    @Published private(set) var playbackState: PlaybackState = .idle
    @Published private(set) var lastErrorMessage: String?

    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var failureObserver: NSObjectProtocol?
    private var stalledObserver: NSObjectProtocol?
    private var isUserPaused = false

    var isPlaying: Bool {
        playbackState == .playing
    }

    func isCurrent(_ station: Station) -> Bool {
        currentStation?.id == station.id
    }

    func play(_ station: Station) {
        guard let url = URL(string: station.streamURL) else {
            failPlayback("Invalid stream URL.")
            return
        }

        teardownObservers()
        currentStation = station
        lastErrorMessage = nil
        isUserPaused = false
        playbackState = .loading
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        attachObservers(to: player, item: item)
        player.play()
    }

    func togglePlayback() {
        switch playbackState {
        case .playing:
            isUserPaused = true
            player?.pause()
            playbackState = .paused
        case .paused:
            isUserPaused = false
            player?.play()
            playbackState = .loading
        case .idle, .failed:
            if let currentStation {
                play(currentStation)
            }
        case .loading:
            isUserPaused = true
            player?.pause()
            playbackState = .paused
        }
    }

    func stop() {
        player?.pause()
        player = nil
        teardownObservers()
        isUserPaused = false
        lastErrorMessage = nil
        currentStation = nil
        playbackState = .idle
    }

    private func attachObservers(to player: AVPlayer, item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }

                switch item.status {
                case .unknown:
                    if !self.isUserPaused {
                        self.playbackState = .loading
                    }
                case .readyToPlay:
                    if !self.isUserPaused && player.timeControlStatus != .waitingToPlayAtSpecifiedRate {
                        self.playbackState = .playing
                    }
                case .failed:
                    self.failPlayback(item.error?.localizedDescription ?? "The stream failed to start.")
                @unknown default:
                    self.failPlayback("The stream entered an unknown playback state.")
                }
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }

                switch player.timeControlStatus {
                case .paused:
                    if self.currentStation == nil {
                        self.playbackState = .idle
                    } else if self.isUserPaused {
                        self.playbackState = .paused
                    }
                case .waitingToPlayAtSpecifiedRate:
                    if !self.isUserPaused {
                        self.playbackState = .loading
                    }
                case .playing:
                    self.lastErrorMessage = nil
                    self.playbackState = .playing
                @unknown default:
                    break
                }
            }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError)?.localizedDescription
            Task { @MainActor in
                self?.failPlayback(error ?? "Playback stopped unexpectedly.")
            }
        }

        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isUserPaused else { return }
                self.playbackState = .loading
            }
        }
    }

    private func failPlayback(_ message: String) {
        lastErrorMessage = message
        playbackState = .failed(message)
    }

    private func teardownObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil

        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
            self.failureObserver = nil
        }

        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
            self.stalledObserver = nil
        }
    }

    deinit {
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
        }
    }
}
