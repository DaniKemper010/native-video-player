import AVFoundation
import Foundation

extension VideoPlayerView {
    func addObservers(to item: AVPlayerItem) {
        item.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
        item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.new], context: nil)
        item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.new], context: nil)

        // Observe player's timeControlStatus to track play/pause state changes
        player?.addObserver(self, forKeyPath: "timeControlStatus", options: [.new, .old], context: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )
    }

    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        // Handle AVPlayerItem observations
        if let item = object as? AVPlayerItem {
            switch keyPath {
            case "status":
                switch item.status {
                case .readyToPlay:
                    // Only send isInitialized for new players, not for shared players
                    // Shared players already sent their state in the init
                    if !isSharedPlayer {
                        sendEvent("isInitialized")
                    }
                case .failed:
                    sendEvent("error", data: ["message": item.error?.localizedDescription ?? "Unknown"])
                default: break
                }
            case "playbackBufferEmpty":
                // For shared players, ignore buffering events when reattaching
                // Only send buffering if the player is actually playing
                if item.isPlaybackBufferEmpty && (!isSharedPlayer || player?.timeControlStatus == .playing) {
                    sendEvent("buffering")
                }
            case "playbackLikelyToKeepUp":
                // For shared players, ignore loading events when reattaching
                // Only send loading if the player is actually playing
                if item.isPlaybackLikelyToKeepUp && (!isSharedPlayer || player?.timeControlStatus == .playing) {
                    sendEvent("loading")
                }
            default: break
            }
        }

        // Handle AVPlayer observations
        if let observedPlayer = object as? AVPlayer, observedPlayer == player {
            switch keyPath {
            case "timeControlStatus":
                guard let player = player else { return }

                switch player.timeControlStatus {
                case .playing:
                    sendEvent("play")
                case .paused:
                    // Only send pause if not waiting to play (buffering)
                    // This prevents sending pause when seeking to unbuffered position
                    if player.reasonForWaitingToPlay == nil {
                        sendEvent("pause")
                    }
                case .waitingToPlayAtSpecifiedRate:
                    // Player is buffering, event already sent by playbackBufferEmpty observer
                    break
                @unknown default:
                    break
                }
            default: break
            }
        }
    }

    @objc func playerItemFailedToPlay(notification: Notification) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            sendEvent("error", data: ["message": error.localizedDescription])
        } else {
            sendEvent("error", data: ["message": "Unknown error"])
        }
    }

    @objc func videoDidEnd() {
        sendEvent("completed")
    }
}