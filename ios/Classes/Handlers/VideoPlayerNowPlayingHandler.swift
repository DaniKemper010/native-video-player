import MediaPlayer
import AVFoundation

// MARK: - Remote Command Manager
/// Singleton to manage MPRemoteCommandCenter ownership
/// Ensures only one VideoPlayerView owns the remote commands at a time
class RemoteCommandManager {
    static let shared = RemoteCommandManager()

    /// Track which view currently owns the remote commands
    private var currentOwnerViewId: Int64?

    /// Lock to prevent race conditions during ownership transfer
    private let lock = NSLock()

    private init() {}

    /// Check if a specific view is the current owner
    func isOwner(_ viewId: Int64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentOwnerViewId == viewId
    }

    /// Set a new owner for remote commands
    func setOwner(_ viewId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        currentOwnerViewId = viewId
        print("🎛️ Remote command ownership transferred to view \(viewId)")
    }

    /// Clear ownership (e.g., when owner is disposed)
    func clearOwner(_ viewId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        if currentOwnerViewId == viewId {
            currentOwnerViewId = nil
            print("🎛️ Remote command ownership cleared from view \(viewId)")
        }
    }

    /// Get the current owner view ID
    func getCurrentOwner() -> Int64? {
        lock.lock()
        defer { lock.unlock() }
        return currentOwnerViewId
    }

    /// Remove all remote command targets
    func removeAllTargets() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        print("🎛️ Removed all remote command targets")
    }

    /// Atomically set owner and remove all targets
    /// This prevents race conditions when multiple views try to register concurrently
    func atomicallySetOwnerAndRemoveTargets(_ viewId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        currentOwnerViewId = viewId
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        print("🎛️ Atomically transferred ownership to view \(viewId) and cleared targets")
    }
}

extension VideoPlayerView {
    /// Sets up the Now Playing info for the Control Center and Lock Screen
    /// This can be called from a background thread safely
    func setupNowPlayingInfo(mediaInfo: [String: Any]) {
        // Defer media session setup by 3 seconds to allow video to start playing smoothly first
        // MPNowPlayingInfoCenter first access BLOCKS MAIN THREAD for 10+ seconds
        // By delaying, the user gets immediate playback, and media controls appear later
        // This is better UX than freezing the UI on play
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }

            var nowPlayingInfo: [String: Any] = [:]

            // --- Core metadata (always available, doesn't block) ---
            if let title = mediaInfo["title"] as? String {
                nowPlayingInfo[MPMediaItemPropertyTitle] = title
            }

            if let subtitle = mediaInfo["subtitle"] as? String {
                nowPlayingInfo[MPMediaItemPropertyArtist] = subtitle
            }

            if let album = mediaInfo["album"] as? String {
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
            }

            // --- Playback rate (doesn't block) ---
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player?.rate ?? 0.0

            // --- Skip duration and elapsed time initially ---
            // These require asset metadata to be loaded, which can block the thread
            // They will be updated later by updateNowPlayingPlaybackTime() which is called
            // from the periodic time observer once the asset is ready

            // --- Commit initial metadata on main thread (MPNowPlayingInfoCenter requires main thread) ---
            // This WILL block the main thread for 10+ seconds on first access, but user is already watching video
            print("🎵 Setting up Now Playing info (this may block briefly on first time)")
            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                print("✅ Now Playing info set successfully")
            }

            // --- Load artwork asynchronously (if available) ---
            // Defer this to avoid any potential blocking from URL validation or URLSession initialization
            if let artworkUrlString = mediaInfo["artworkUrl"] as? String {
                // Validate URL on background thread to avoid any potential blocking
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    guard let self = self,
                          let artworkUrl = URL(string: artworkUrlString) else {
                        return
                    }

                    self.loadArtwork(from: artworkUrl) { [weak self] image in
                        guard let self = self,
                              let image = image
                        else {
                            return
                        }

                        DispatchQueue.main.async {
                            var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                                image
                            }
                            updatedInfo[MPMediaItemPropertyArtwork] = artwork
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                        }
                    }
                }
            }

            // --- Setup remote commands asynchronously to avoid blocking UI ---
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.setupRemoteCommandCenter()
            }
        }
    }

    /// Loads artwork image from URL
    /// Should be called from a background thread
    private func loadArtwork(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }

            // Decode image on a background thread - UIImage(data:) can be slow for large images
            DispatchQueue.global(qos: .utility).async {
                guard let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                completion(image)
            }
        }
        .resume()
    }

    /// Sets up remote command center for Control Center controls
    /// Only registers if this view should be the owner
    /// This can be called from a background thread safely
    private func setupRemoteCommandCenter() {
        // MPRemoteCommandCenter must be accessed on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let commandCenter = MPRemoteCommandCenter.shared()

            // Atomically take ownership and clear all existing targets
            // This prevents race conditions when multiple views try to register concurrently
            RemoteCommandManager.shared.atomicallySetOwnerAndRemoveTargets(self.viewId)

            // --- Play ---
            commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }

            // Only handle if we still own the remote commands
            guard RemoteCommandManager.shared.isOwner(self.viewId) else {
                print("⚠️ View \(self.viewId) received play command but is not owner")
                return .commandFailed
            }

            self.player?.play()
            self.sendEvent("play")
            self.updateNowPlayingPlaybackTime()
            return .success
        }

        // --- Pause ---
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }

            // Only handle if we still own the remote commands
            guard RemoteCommandManager.shared.isOwner(self.viewId) else {
                print("⚠️ View \(self.viewId) received pause command but is not owner")
                return .commandFailed
            }

            self.player?.pause()
            self.sendEvent("pause")
            self.updateNowPlayingPlaybackTime()
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

            // Only handle if we still own the remote commands
            guard RemoteCommandManager.shared.isOwner(self.viewId) else {
                print("⚠️ View \(self.viewId) received skip forward command but is not owner")
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

            // Only handle if we still own the remote commands
            guard RemoteCommandManager.shared.isOwner(self.viewId) else {
                print("⚠️ View \(self.viewId) received skip backward command but is not owner")
                return .commandFailed
            }

            let currentTime = player.currentTime()
            let newTime = CMTimeSubtract(currentTime, CMTime(seconds: skipEvent.interval, preferredTimescale: 600))
            player.seek(to: max(newTime, .zero))
                self.updateNowPlayingPlaybackTime()
                return .success
            }

            print("🎛️ View \(self.viewId) registered remote command handlers")
        }
    }

    /// Updates playback time and rate dynamically (e.g., every second or on state change)
    /// Can be called from any thread - dispatches to main thread for MPNowPlayingInfoCenter access
    func updateNowPlayingPlaybackTime() {
        guard let player = player else {
            return
        }

        let isPlaying = player.rate > 0

        // Only allow updates if this view owns the remote commands
        // This prevents multiple views from fighting over Now Playing info
        guard RemoteCommandManager.shared.isOwner(viewId) else {
            if isPlaying {
                print("⚠️ View \(viewId) is playing but doesn't own remote commands")
            }
            return
        }

        // Get current playback state on current thread (doesn't require main thread)
        let currentTime = player.currentTime()
        let elapsedSeconds = CMTimeGetSeconds(currentTime)
        let currentRate = player.rate

        // MPNowPlayingInfoCenter MUST be accessed on main thread
        // Use async to avoid blocking the caller
        DispatchQueue.main.async {
            var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

            if elapsedSeconds.isFinite {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
            }

            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = currentRate
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
}
