import AVFoundation
import Foundation

extension VideoPlayerView {
    func addObservers(to item: AVPlayerItem) {
        item.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
        item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.new], context: nil)
        item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.new], context: nil)

        // Observe player's timeControlStatus to track play/pause state changes
        player?.addObserver(self, forKeyPath: "timeControlStatus", options: [.new, .old], context: nil)

        // Observe AirPlay connection status
        player?.addObserver(self, forKeyPath: "externalPlaybackActive", options: [.new, .initial], context: nil)

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
                // Send buffering event when buffer is empty
                // This is important for seeking while paused
                if item.isPlaybackBufferEmpty {
                    sendEvent("buffering")
                }
            case "playbackLikelyToKeepUp":
                // Send loading event when buffer is ready, then restore playback state
                // This is important for seeking while paused - user needs to know buffering is done
                if item.isPlaybackLikelyToKeepUp {
                    sendEvent("loading")
                    
                    // Restore the playback state after buffering completes
                    // This tells the UI whether the video is playing or paused
                    if let player = player {
                        if player.rate > 0 && player.timeControlStatus == .playing {
                            sendEvent("play")
                        } else if player.timeControlStatus == .paused && player.reasonForWaitingToPlay == nil {
                            sendEvent("pause")
                        }
                    }
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
            case "externalPlaybackActive":
                guard let player = player else { return }
                let isActive = player.isExternalPlaybackActive
                print("AVPlayer externalPlaybackActive changed to: \(isActive)")
                sendEvent("airPlayConnectionChanged", data: ["isConnected": isActive])
            default: break
            }
        }

        // Handle AVRouteDetector observations
        if #available(iOS 11.0, *) {
            if let detector = object as? AVRouteDetector, detector == routeDetector {
                switch keyPath {
                case "multipleRoutesDetected":
                    let isAvailable = routeDetector?.multipleRoutesDetected ?? false
                    print("AVRouteDetector multipleRoutesDetected changed to: \(isAvailable)")
                    sendEvent("airPlayAvailabilityChanged", data: ["isAvailable": isAvailable])
                default: break
                }
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

    // MARK: - AirPlay Route Detection

    /// Sets up AVRouteDetector to monitor AirPlay availability
    @available(iOS 11.0, *)
    func setupAirPlayRouteDetector() {
        print("Setting up AirPlay route detector")
        routeDetector = AVRouteDetector()
        routeDetector?.isRouteDetectionEnabled = true

        // Observe changes to multipleRoutesDetected
        routeDetector?.addObserver(
            self,
            forKeyPath: "multipleRoutesDetected",
            options: [.new, .initial],
            context: nil
        )

        print("AirPlay route detector setup complete, multipleRoutesDetected: \(routeDetector?.multipleRoutesDetected ?? false)")
    }

    /// Observes AirPlay route availability changes
    @objc func handleAirPlayRouteChange() {
        if #available(iOS 11.0, *) {
            if let isAvailable = routeDetector?.multipleRoutesDetected {
                sendEvent("airPlayAvailabilityChanged", data: ["isAvailable": isAvailable])
            }
        }
    }
}