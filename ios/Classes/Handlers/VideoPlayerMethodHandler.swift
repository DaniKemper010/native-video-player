import Flutter
import AVFoundation
import MediaPlayer

extension VideoPlayerView {

    func handleLoad(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("handleLoad called with arguments: \(String(describing: call.arguments))")

        guard let arguments = call.arguments as? [String: Any],
              let urlString = arguments["url"] as? String,
              let url = URL(string: urlString)
        else {
            let error = FlutterError(code: "INVALID_URL", message: "Invalid URL provided", details: nil)
            result(error)
            return
        }

        let autoPlay = arguments["autoPlay"] as? Bool ?? false
        let headers = arguments["headers"] as? [String: String]
        let mediaInfo = arguments["mediaInfo"] as? [String: Any]

        // Store media info for Now Playing
        if let mediaInfo = mediaInfo {
            currentMediaInfo = mediaInfo
        }

        sendEvent("loading")

        // Fetch qualities (async)
        fetchHLSQualities(from: url) { [weak self] qualities in
            self?.availableQualities = qualities
        }

        // --- Build player item ---
        let playerItem: AVPlayerItem
        if let headers = headers {
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            playerItem = AVPlayerItem(asset: asset)
        } else {
            playerItem = AVPlayerItem(url: url)
        }

        player?.replaceCurrentItem(with: playerItem)

        // --- Set up periodic time observer for Now Playing elapsed time updates ---
        setupPeriodicTimeObserver()

        // --- Set up audio session ---
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)

        // --- Listen for end of playback ---
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // --- Observe status (wait for ready) ---
        var statusObserver: NSKeyValueObservation?
        statusObserver = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self = self else {
                return
            }

            switch item.status {
            case .readyToPlay:
                print("🎬 Video ready to play")

                // Send Flutter event
                self.sendEvent("videoLoaded")

                // Set now playing info *after* player item is ready
                if let mediaInfo = mediaInfo {
                    self.setupNowPlayingInfo(mediaInfo: mediaInfo)
                }

                // Auto play if requested
                if autoPlay {
                    self.player?.play()
                    self.sendEvent("play")
                }

                // Release observer (avoid leaks)
                statusObserver?.invalidate()

                result(nil)

            case .failed:
                let error = item.error?.localizedDescription ?? "Unknown error"
                result(FlutterError(code: "LOAD_ERROR", message: error, details: nil))

            case .unknown:
                break

            @unknown default:
                break
            }
        }
    }


    func handlePlay(result: @escaping FlutterResult) {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        updateNowPlayingPlaybackTime()
        sendEvent("play")
        result(nil)
    }

    func handlePause(result: @escaping FlutterResult) {
        player?.pause()
        updateNowPlayingPlaybackTime()
        sendEvent("pause")
        result(nil)
    }

    func handleSeekTo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let milliseconds = call.arguments as? Int {
            let seconds = Double(milliseconds) / 1000.0
            player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000)) { _ in
                self.sendEvent("seek", data: ["position": milliseconds])
                self.updateNowPlayingPlaybackTime()
            }
        }
        result(nil)
    }

    func handleSetVolume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let volume = call.arguments as? Double {
            player?.volume = Float(volume)
        }
        result(nil)
    }

    func handleSetSpeed(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let speed = call.arguments as? Double {
            player?.rate = Float(speed)
            sendEvent("speedChange", data: ["speed": speed])
            result(nil)
        } else {
            result(FlutterError(code: "INVALID_SPEED", message: "Invalid speed value", details: nil))
        }
    }

    func handleSetQuality(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let qualityInfo = call.arguments as? [String: String],
           let urlString = qualityInfo["url"],
           let url = URL(string: urlString) {

            sendEvent("loading")

            let currentTime = player?.currentTime() ?? CMTime.zero
            let newItem = AVPlayerItem(url: url)
            player?.replaceCurrentItem(with: newItem)
            player?.seek(to: currentTime)
            player?.play()
            sendEvent("qualityChange", data: ["url": urlString, "label": qualityInfo["label"] ?? ""])
            result(nil)
        } else {
            result(FlutterError(code: "INVALID_QUALITY", message: "Invalid quality data", details: nil))
        }
    }

    func handleDispose(result: @escaping FlutterResult) {
        player?.pause()

        // Remove from shared manager if this is a shared player
        if let controllerId = controllerId {
            SharedPlayerManager.shared.removePlayer(for: controllerId)
            print("Removed shared player for controller ID: \(controllerId)")
        }

        player = nil
        sendEvent("stopped")
        result(nil)
    }

    func handleEnterFullScreen(result: @escaping FlutterResult) {
        if let viewController = UIApplication.shared.keyWindow?.rootViewController {
            // Present player view controller in fullscreen
            viewController.present(playerViewController, animated: true) {
                // Send event after animation completes
                self.sendEvent("fullscreenChange", data: ["isFullscreen": true])
                result(nil)
            }
        } else {
            result(FlutterError(code: "FULLSCREEN_ERROR", message: "Could not present fullscreen player", details: nil))
        }
    }

    func handleExitFullScreen(result: @escaping FlutterResult) {
        // Dismiss player view controller
        playerViewController.dismiss(animated: true) {
            // Send event after animation completes
            self.sendEvent("fullscreenChange", data: ["isFullscreen": false])
            result(nil)
        }
    }

    /// Sets up periodic time observer to update Now Playing elapsed time
    func setupPeriodicTimeObserver() {
        // Remove existing observer if any
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        // Update Now Playing info every second
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.updateNowPlayingPlaybackTime()
        }
    }
}