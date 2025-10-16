import MediaPlayer
import AVFoundation

extension VideoPlayerView {
    /// Sets up the Now Playing info for the Control Center and Lock Screen
    func setupNowPlayingInfo(mediaInfo: [String: Any]) {
        var nowPlayingInfo: [String: Any] = [:]

        // --- Core metadata ---
        if let title = mediaInfo["title"] as? String {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }

        if let subtitle = mediaInfo["subtitle"] as? String {
            nowPlayingInfo[MPMediaItemPropertyArtist] = subtitle
        }

        if let album = mediaInfo["album"] as? String {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }

        // --- Playback duration & elapsed time ---
        if let duration = player?.currentItem?.asset.duration {
            let durationSeconds = CMTimeGetSeconds(duration)
            if durationSeconds.isFinite {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = durationSeconds
            }
        }

        if let currentTime = player?.currentTime() {
            let elapsedSeconds = CMTimeGetSeconds(currentTime)
            if elapsedSeconds.isFinite {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
            }
        }

        // --- Playback rate (0 = paused, 1 = playing) ---
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0.0

        // --- Commit initial metadata immediately (before artwork loads) ---
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // --- Load artwork asynchronously (if available) ---
        if let artworkUrlString = mediaInfo["artworkUrl"] as? String,
           let artworkUrl = URL(string: artworkUrlString) {

            loadArtwork(from: artworkUrl) { [weak self] image in
                guard let self = self,
                      let image = image
                else {
                    return
                }

                var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                    image
                }
                updatedInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
            }
        }

        // --- Setup remote commands (if not already done) ---
        setupRemoteCommandCenter()
    }

    /// Loads artwork image from URL
    private func loadArtwork(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }
        .resume()
    }

    /// Sets up remote command center for Control Center controls
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Avoid multiple bindings (prevents duplicate callbacks)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)

        // --- Play ---
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.sendEvent("play")
            self?.updateNowPlayingPlaybackTime()
            return .success
        }

        // --- Pause ---
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.sendEvent("pause")
            self?.updateNowPlayingPlaybackTime()
            return .success
        }

        // --- Skip forward/backward ---
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.preferredIntervals = [15]

        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent,
                  let player = self.player
            else {
                return .commandFailed
            }

            let currentTime = player.currentTime()
            let newTime = CMTimeAdd(currentTime, CMTime(seconds: skipEvent.interval, preferredTimescale: 600))
            player.seek(to: newTime)
            self.updateNowPlayingPlaybackTime()
            return .success
        }

        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent,
                  let player = self.player
            else {
                return .commandFailed
            }

            let currentTime = player.currentTime()
            let newTime = CMTimeSubtract(currentTime, CMTime(seconds: skipEvent.interval, preferredTimescale: 600))
            player.seek(to: max(newTime, .zero))
            self.updateNowPlayingPlaybackTime()
            return .success
        }
    }

    /// Updates playback time and rate dynamically (e.g., every second or on state change)
    func updateNowPlayingPlaybackTime() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return
        }

        if let currentTime = player?.currentTime() {
            let elapsedSeconds = CMTimeGetSeconds(currentTime)
            if elapsedSeconds.isFinite {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
            }
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
