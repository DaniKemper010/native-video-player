import Flutter
import AVFoundation
import AVKit
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
        VideoPlayerQualityHandler.fetchHLSQualities(from: url) { [weak self] qualities in
            self?.qualityLevels = qualities
            
            // Convert to Flutter format
            var result: [[String: Any]] = []
            
            // Add auto quality option
            result.append([
                "label": "Auto",
                "url": qualities.first?.url ?? "",
                "isAuto": true
            ])
            
            // Add all available qualities
            result.append(contentsOf: qualities.map { quality in
                [
                    "label": quality.label,
                    "url": quality.url,
                    "bitrate": quality.bitrate,
                    "width": Int(quality.resolution.width),
                    "height": Int(quality.resolution.height),
                    "isAuto": false
                ]
            })
            
            // Send qualities to Flutter
            self?.availableQualities = result
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

                // Get duration
                let duration = item.duration
                let durationSeconds = CMTimeGetSeconds(duration)

                // Send Flutter event with duration (only if valid)
                if durationSeconds.isFinite && !durationSeconds.isNaN {
                    let totalDuration = Int(durationSeconds * 1000) // milliseconds
                    self.sendEvent("videoLoaded", data: [
                        "duration": totalDuration
                    ])
                } else {
                    self.sendEvent("videoLoaded")
                }

                // Set now playing info *after* player item is ready
                if let mediaInfo = mediaInfo {
                    self.setupNowPlayingInfo(mediaInfo: mediaInfo)
                }

                // Set up PiP controller if available
                if #available(iOS 14.0, *) {
                    if AVPictureInPictureController.isPictureInPictureSupported(),
                       let player = self.player {
                        // Create a player layer from the player
                        let playerLayer = AVPlayerLayer(player: player)
                        if let pipController = try? AVPictureInPictureController(playerLayer: playerLayer) {
                            self.pipController = pipController
                        }
                    }
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
        if let args = call.arguments as? [String: Any],
           let milliseconds = args["milliseconds"] as? Int {
            let seconds = Double(milliseconds) / 1000.0
            player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000)) { _ in
                self.sendEvent("seek", data: ["position": milliseconds])
                self.updateNowPlayingPlaybackTime()
            }
        }
        result(nil)
    }

    func handleSetVolume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any],
           let volume = args["volume"] as? Double {
            player?.volume = Float(volume)
        }
        result(nil)
    }

    func handleSetSpeed(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any],
           let speed = args["speed"] as? Double {
            player?.rate = Float(speed)
            sendEvent("speedChange", data: ["speed": speed])
            result(nil)
        } else {
            result(FlutterError(code: "INVALID_SPEED", message: "Invalid speed value", details: nil))
        }
    }

    // Auto-quality handling
    
    func handleSetQuality(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let qualityInfo = args["quality"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_QUALITY", message: "Invalid quality data", details: nil))
            return
        }
        
        let isAuto = qualityInfo["isAuto"] as? Bool ?? false
        isAutoQuality = isAuto
        
        if isAuto {
            // Start with the middle quality for auto mode
            let midIndex = max(0, qualityLevels.count / 2 - 1)
            guard midIndex < qualityLevels.count else {
                result(FlutterError(code: "NO_QUALITIES", message: "No qualities available", details: nil))
                return
            }
            
            let initialQuality = qualityLevels[midIndex]
            switchToQuality(initialQuality, result: result)
            
            // Enable quality monitoring
            startQualityMonitoring()
        } else {
            guard let urlString = qualityInfo["url"] as? String,
                  let url = URL(string: urlString) else {
                result(FlutterError(code: "INVALID_URL", message: "Invalid quality URL", details: nil))
                return
            }
            
            sendEvent("loading")
            
            // Store current playback state and position
            let wasPlaying = player?.rate != 0
            let currentTime = player?.currentTime() ?? CMTime.zero
            
            let newItem = AVPlayerItem(url: url)
            player?.replaceCurrentItem(with: newItem)
            player?.seek(to: currentTime)
            
            // Only resume playback if it was playing before
            if wasPlaying {
                player?.play()
            }
            
            sendEvent("qualityChange", data: [
                "url": urlString,
                "label": qualityInfo["label"] as? String ?? "",
                "isAuto": false
            ])
            result(nil)
        }
    }
    
    private func startQualityMonitoring() {
        // Remove existing observer if any
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        // Monitor playback every second for auto-quality
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.checkAndAdjustQuality()
        }
    }
    
    private func checkAndAdjustQuality() {
        guard isAutoQuality,
              !qualityLevels.isEmpty,
              CACurrentMediaTime() - lastBitrateCheck >= bitrateCheckInterval else {
            return
        }
        
        lastBitrateCheck = CACurrentMediaTime()
        
        // Get current playback statistics
        let loadedTimeRanges = player?.currentItem?.loadedTimeRanges ?? []
        let currentTime = player?.currentTime() ?? CMTime.zero
        
        // Calculate buffer health
        var bufferHealth: TimeInterval = 0
        for range in loadedTimeRanges {
            let timeRange = range.timeRangeValue
            if timeRange.start <= currentTime {
                bufferHealth += timeRange.duration.seconds
            }
        }
        
        // Get current quality index
        guard let urlAsset = player?.currentItem?.asset as? AVURLAsset,
              let currentUrl = urlAsset.url.absoluteString as String?,
              let currentIndex = qualityLevels.firstIndex(where: { $0.url == currentUrl }) else {
            return
        }
        
        // Adjust quality based on buffer health
        var targetIndex = currentIndex
        
        if bufferHealth < 3.0 && currentIndex > 0 {
            // Buffer is low, decrease quality
            targetIndex = currentIndex - 1
        } else if bufferHealth > 10.0 && currentIndex < qualityLevels.count - 1 {
            // Buffer is healthy, try increasing quality
            targetIndex = currentIndex + 1
        }
        
        if targetIndex != currentIndex {
            switchToQuality(qualityLevels[targetIndex], result: nil)
        }
    }
    
    private func switchToQuality(_ quality: VideoPlayer.QualityLevel, result: FlutterResult?) {
        guard let url = URL(string: quality.url) else {
            result?(FlutterError(code: "INVALID_URL", message: "Invalid quality URL", details: nil))
            return
        }
        
        sendEvent("loading")
        
        let wasPlaying = player?.rate != 0
        let currentTime = player?.currentTime() ?? CMTime.zero
        
        let newItem = AVPlayerItem(url: url)
        player?.replaceCurrentItem(with: newItem)
        player?.seek(to: currentTime)
        
        if wasPlaying {
            player?.play()
        }
        
        sendEvent("qualityChange", data: [
            "url": quality.url,
            "label": quality.label,
            "isAuto": isAutoQuality
        ])
        
        result?(nil)
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
            // Create a NEW player view controller for fullscreen
            // This prevents the embedded view from being removed from Flutter's view hierarchy
            let fullscreenPlayerViewController = AVPlayerViewController()
            fullscreenPlayerViewController.player = player
            fullscreenPlayerViewController.showsPlaybackControls = true
            fullscreenPlayerViewController.delegate = self

            // Store reference to dismiss later
            self.fullscreenPlayerViewController = fullscreenPlayerViewController

            viewController.present(fullscreenPlayerViewController, animated: true) {
                // Send event after animation completes
                self.sendEvent("fullscreenChange", data: ["isFullscreen": true])
                result(nil)
            }
        } else {
            result(FlutterError(code: "FULLSCREEN_ERROR", message: "Could not present fullscreen player", details: nil))
        }
    }

    func handleExitFullScreen(result: @escaping FlutterResult) {
        // Dismiss the fullscreen player view controller if it exists
        if let fullscreenVC = fullscreenPlayerViewController {
            fullscreenVC.dismiss(animated: true) {
                // Clear the reference
                self.fullscreenPlayerViewController = nil

                self.sendEvent("fullscreenChange", data: ["isFullscreen": false])
                result(nil)
            }
        } else {
            // Fallback: dismiss the embedded player controller (shouldn't happen)
            playerViewController.dismiss(animated: true) {
                self.sendEvent("fullscreenChange", data: ["isFullscreen": false])
                result(nil)
            }
        }
    }

    func handleIsPictureInPictureAvailable(result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            // Check if PiP is supported on this device
            let isPipSupported = AVPictureInPictureController.isPictureInPictureSupported()
            result(isPipSupported)
        } else {
            // PiP requires iOS 14.0+
            result(false)
        }
    }

    func handleEnterPictureInPicture(result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            if let pipController = pipController {
                if pipController.isPictureInPicturePossible {
                    pipController.startPictureInPicture()
                    result(true)
                } else {
                    result(FlutterError(code: "PIP_NOT_POSSIBLE", message: "Picture-in-Picture is not possible at this time", details: nil))
                }
            } else {
                result(FlutterError(code: "PIP_NOT_INITIALIZED", message: "Picture-in-Picture controller not initialized", details: nil))
            }
        } else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "PiP not supported on this iOS version", details: nil))
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
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self, let player = self.player else { return }

            // Update Now Playing info
            self.updateNowPlayingPlaybackTime()

            // Send timeUpdate event to Flutter
            let currentTime = player.currentTime()
            let duration = player.currentItem?.duration ?? CMTime.zero

            let positionSeconds = CMTimeGetSeconds(currentTime)
            let durationSeconds = CMTimeGetSeconds(duration)

            // Get buffered position
            var bufferedSeconds = 0.0
            if let timeRanges = player.currentItem?.loadedTimeRanges, !timeRanges.isEmpty {
                // Get the most recent buffered range
                let bufferedRange = timeRanges.last!.timeRangeValue
                let bufferedEnd = CMTimeAdd(bufferedRange.start, bufferedRange.duration)
                bufferedSeconds = CMTimeGetSeconds(bufferedEnd)
            }

            // Only send event if values are valid (not NaN or Infinity)
            if positionSeconds.isFinite && !positionSeconds.isNaN &&
               durationSeconds.isFinite && !durationSeconds.isNaN && durationSeconds > 0 {
                let position = Int(positionSeconds * 1000) // milliseconds
                let totalDuration = Int(durationSeconds * 1000) // milliseconds
                let bufferedPosition = Int(bufferedSeconds * 1000) // milliseconds

                self.sendEvent("timeUpdate", data: [
                    "position": position,
                    "duration": totalDuration,
                    "bufferedPosition": bufferedPosition
                ])
            }
        }
    }
}