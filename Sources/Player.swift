import AVFoundation
import MediaPlayer
import Observation
import UIKit

@MainActor @Observable
final class Player {
    static let shared = Player()

    private(set) var queue: [Song] = []
    private(set) var index = 0
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var progress: Double = 0
    private(set) var duration: Double = 0
    var error: String?
    var showFullPlayer = false

    var current: Song? { queue.indices.contains(index) ? queue[index] : nil }

    @ObservationIgnored private let av = AVPlayer()
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var artworkImage: UIImage?

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        _ = av.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in self?.tick(time) }
        }
        setupRemote()
    }

    // MARK: Controls

    func play(_ song: Song, in list: [Song]) {
        queue = list.contains(song) ? list : [song]
        index = queue.firstIndex(of: song) ?? 0
        load()
    }

    func toggle() {
        if av.timeControlStatus == .paused {
            if av.currentItem == nil { load() } else { av.play() }
            isPlaying = true
        } else {
            av.pause()
            isPlaying = false
        }
        publishInfo()
    }

    func next() {
        guard index + 1 < queue.count else {
            av.pause()
            isPlaying = false
            seek(to: 0)
            return
        }
        index += 1
        load()
    }

    func previous() {
        if progress > 3 || index == 0 {
            seek(to: 0)
        } else {
            index -= 1
            load()
        }
    }

    func seek(to seconds: Double) {
        av.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        progress = seconds
        publishInfo()
    }

    // MARK: Loading

    private func load() {
        guard let song = current else { return }
        loadTask?.cancel()
        isLoading = true
        error = nil
        progress = 0
        duration = song.duration ?? 0
        artworkImage = nil
        publishInfo()

        loadTask = Task {
            do {
                let url: URL
                if let local = Downloads.shared.localURL(for: song) {
                    url = local
                } else {
                    url = try await ModuleStore.shared.resolve(song, download: false)
                }
                try Task.checkCancellation()
                let item = AVPlayerItem(url: url)
                watchEnd(of: item)
                av.replaceCurrentItem(with: item)
                av.play()
                isPlaying = true
                isLoading = false
                await loadArtwork(for: song)
            } catch is CancellationError {
            } catch {
                isLoading = false
                isPlaying = false
                self.error = error.localizedDescription
            }
        }
    }

    private func watchEnd(of item: AVPlayerItem) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.next() }
        }
    }

    private func tick(_ time: CMTime) {
        if time.seconds.isFinite { progress = time.seconds }
        isPlaying = av.timeControlStatus != .paused
        if let d = av.currentItem?.duration.seconds, d.isFinite, d > 0, abs(d - duration) > 0.5 {
            duration = d
            publishInfo()
        }
        if let item = av.currentItem, item.status == .failed {
            error = item.error?.localizedDescription ?? "Cannot play this audio"
        }
    }

    // MARK: Lock screen

    private func loadArtwork(for song: Song) async {
        guard let s = song.artwork, let url = URL(string: s),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data), current == song else { return }
        artworkImage = image
        publishInfo()
    }

    private func publishInfo() {
        guard let song = current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let image = artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemote() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == false { self?.toggle() } }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == true { self?.toggle() } }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                let t = e.positionTime
                Task { @MainActor in self?.seek(to: t) }
            }
            return .success
        }
    }
}
