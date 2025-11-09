import Flutter
import AVFoundation
import AVKit
import MediaPlayer

// Add reference to VideoPlayerView in the extension scope
extension VideoPlayerView {

    func handleLoad(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let t0 = Date().timeIntervalSince1970
        print("⏱️ [T+0.000s] ========== handleLoad START ==========")
        print("⏱️ [T+0.000s] Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
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
            print("📱 Stored media info during load: \(mediaInfo["title"] ?? "Unknown")")
        } else {
            print("⚠️ No media info provided during load")
        }

        // Send loading event and return immediately to avoid blocking Flutter
        print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] About to send 'loading' event...")
        sendEvent("loading")
        print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Sent 'loading' event, returning result...")
        result(nil)  // Return immediately - don't block the UI
        print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ Returned from handleLoad - loading continues async")

        // Determine if this is likely an HLS stream
        let isHls = isHlsUrl(url)
        print("🎬 Loading video - URL: \(urlString), isHLS: \(isHls)")

        // Fetch qualities asynchronously (non-blocking) for HLS streams
        // IMPORTANT: Don't wait for this - let it happen in parallel
        if isHls {
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Starting async HLS quality fetch (non-blocking)...")
            DispatchQueue.global(qos: .utility).async { [weak self] in
                VideoPlayerQualityHandler.fetchHLSQualities(from: url) { [weak self] qualities in
                    guard let self = self else { return }

                    self.qualityLevels = qualities

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
                    self.availableQualities = result

                    // Store in SharedPlayerManager if this is a shared player
                    if let controllerIdValue = self.controllerId {
                        SharedPlayerManager.shared.setQualities(
                            for: controllerIdValue,
                            qualities: result,
                            qualityLevels: qualities
                        )
                    }
                    print("⏱️ HLS qualities loaded: \(qualities.count) qualities")
                }
            }
        } else {
            print("🎬 Skipping quality fetch for non-HLS content")
        }

        // --- Build player item - CRITICAL: Create on MAIN thread for streaming URLs ---
        // Even AVPlayerItem(url:) blocks for 5+ seconds on background threads due to network I/O
        // The solution: Create and apply the player item on the MAIN thread IMMEDIATELY
        // Let AVPlayer handle all streaming asynchronously - don't wait for anything!
        print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Creating player item on MAIN thread for instant streaming...")
        DispatchQueue.main.async { [weak self, t0] in
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ▶️ ENTERED MAIN thread")
            print("⏱️ Thread: \(Thread.isMainThread ? "MAIN ✓" : "BACKGROUND ⚠️")")
            guard let self = self else { return }

            // CRITICAL DISCOVERY: AVURLAsset creation blocks for 6+ seconds on network URLs
            // even on background threads, even with options to prevent it.
            // Solution: Use AVPlayerItem(url:) directly for remote URLs - it's designed for streaming!
            // Only use AVURLAsset for local files where preloading works instantly.

            let isRemoteUrl = url.scheme == "http" || url.scheme == "https"
            let playerItem: AVPlayerItem

            if isRemoteUrl {
                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] 🌐 Remote URL - creating AVPlayerItem directly (no preloading)...")
                let itemStart = Date().timeIntervalSince1970

                if let headers = headers, !headers.isEmpty {
                    // For remote URLs with headers, we still need AVURLAsset
                    let options: [String: Any] = [
                        "AVURLAssetHTTPHeaderFieldsKey": headers
                    ]
                    let asset = AVURLAsset(url: url, options: options)
                    playerItem = AVPlayerItem(asset: asset)
                } else {
                    // For remote URLs without headers, use the direct initializer
                    // This is MUCH faster and non-blocking for streaming content
                    playerItem = AVPlayerItem(url: url)
                }

                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ AVPlayerItem created directly (took \(String(format: "%.3f", Date().timeIntervalSince1970 - itemStart))s)")

                // Continue with the rest of the setup immediately - no waiting!
                self.setupPlayerItem(playerItem, autoPlay: autoPlay, t0: t0)

            } else {
                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] 📁 Local file - preloading with AVURLAsset...")
                let assetStart = Date().timeIntervalSince1970

                var options: [String: Any] = [:]
                if let headers = headers {
                    options["AVURLAssetHTTPHeaderFieldsKey"] = headers
                }

                let asset = AVURLAsset(url: url, options: options)
                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ AVURLAsset created (took \(String(format: "%.3f", Date().timeIntervalSince1970 - assetStart))s)")

                // Preload essential properties for local files (fast!)
                let keysToLoad = ["tracks", "duration", "playable"]
                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Starting loadValuesAsynchronously for: \(keysToLoad)...")
                let loadStart = Date().timeIntervalSince1970
                asset.loadValuesAsynchronously(forKeys: keysToLoad) { [weak self, t0] in
                    print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] 📥 loadValuesAsynchronously CALLBACK (took \(String(format: "%.3f", Date().timeIntervalSince1970 - loadStart))s)")
                    print("⏱️ Thread: \(Thread.isMainThread ? "MAIN ⚠️" : "BACKGROUND ✓")")
                    guard let self = self else { return }

                    // Verify all keys loaded successfully
                    var allKeysLoaded = true
                    for key in keysToLoad {
                        var error: NSError?
                        let status = asset.statusOfValue(forKey: key, error: &error)
                        print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s]   Property '\(key)': \(status.rawValue == 2 ? "✓ loaded" : "✗ status=\(status.rawValue)")")
                        if status == .failed {
                            print("❌ Failed to load asset property '\(key)': \(error?.localizedDescription ?? "unknown error")")
                            allKeysLoaded = false
                            DispatchQueue.main.async {
                                self.sendEvent("error", data: ["message": "Failed to load video metadata: \(error?.localizedDescription ?? "unknown")"])
                            }
                            return
                        } else if status == .cancelled {
                            print("⚠️ Loading cancelled for property '\(key)'")
                            allKeysLoaded = false
                            return
                        }
                    }

                    guard allKeysLoaded else { return }
                    print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ All asset properties preloaded")

                    // Now create the player item with the fully loaded asset
                    print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Creating AVPlayerItem...")
                    let itemStart = Date().timeIntervalSince1970
                    let playerItem = AVPlayerItem(asset: asset)
                    print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ AVPlayerItem created (took \(String(format: "%.3f", Date().timeIntervalSince1970 - itemStart))s)")

                    // Continue with the rest of the setup
                    self.setupPlayerItem(playerItem, autoPlay: autoPlay, t0: t0)
                }
            }

            // --- Set up audio session asynchronously to avoid blocking ---
            let audioStart = Date().timeIntervalSince1970
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Setting up audio session...")
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                    try AVAudioSession.sharedInstance().setActive(true)
                    print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ Audio session configured")
                } catch {
                    print("❌ Failed to configure AVAudioSession: \(error.localizedDescription)")
                }
            }
        }
    }

    // Common setup function for both remote and local player items
    private func setupPlayerItem(_ playerItem: AVPlayerItem, autoPlay: Bool, t0: TimeInterval) {
        // --- Skip HDR settings - AVPlayer handles tone-mapping automatically ---
        // Removed video composition code that was blocking for 5+ seconds
        // Modern AVPlayer automatically tone-maps HDR to SDR when needed
        if !self.enableHDR {
            print("🎨 HDR disabled - AVPlayer will automatically tone-map HDR content to SDR")
        } else {
            print("🎨 HDR enabled - allowing native HDR playback")
        }

        // Apply to player on main thread
        print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Dispatching to MAIN thread...")
        let mainDispatchTime = Date().timeIntervalSince1970
        DispatchQueue.main.async { [weak self, playerItem, t0] in
            let mainEnter = Date().timeIntervalSince1970
            print("⏱️ [T+\(String(format: "%.3f", mainEnter - t0))s] ▶️▶️ ENTERED MAIN THREAD (dispatch lag: \(String(format: "%.3f", mainEnter - mainDispatchTime))s)")
            print("⏱️ Thread: \(Thread.isMainThread ? "MAIN ✓" : "BACKGROUND ⚠️")")
            guard let self = self else { return }

            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Calling replaceCurrentItem...")
            let replaceStart = Date().timeIntervalSince1970
            self.player?.replaceCurrentItem(with: playerItem)
            let replaceEnd = Date().timeIntervalSince1970
            print("⏱️ [T+\(String(format: "%.3f", replaceEnd - t0))s] ✅✅ replaceCurrentItem COMPLETED (took \(String(format: "%.3f", replaceEnd - replaceStart))s)")

            // --- Set up observers for buffer status and player state ---
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Adding observers...")
            let obsStart = Date().timeIntervalSince1970
            self.addObservers(to: playerItem)
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ Observers added (took \(String(format: "%.3f", Date().timeIntervalSince1970 - obsStart))s)")

            // --- Set up periodic time observer for Now Playing elapsed time updates ---
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Setting up periodic time observer...")
            let timeObsStart = Date().timeIntervalSince1970
            self.setupPeriodicTimeObserver()
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ Time observer setup (took \(String(format: "%.3f", Date().timeIntervalSince1970 - timeObsStart))s)")

            // --- Listen for end of playback ---
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Adding notification observer...")
            let notifStart = Date().timeIntervalSince1970
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.videoDidEnd),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ Notification observer added (took \(String(format: "%.3f", Date().timeIntervalSince1970 - notifStart))s)")
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ◀️◀️ EXITING MAIN THREAD")
        }

        // --- Observe status (wait for ready) ---
        print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Setting up status observer...")
        var statusObserver: NSKeyValueObservation?
        statusObserver = playerItem.observe(\.status, options: [.initial, .new]) { [weak self, t0] item, _ in
            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] 📢📢 Status observer callback - status: \(item.status.rawValue)")
            print("⏱️ Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
            guard let self = self else {
                return
            }

            switch item.status {
            case .readyToPlay:
                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] 🎬🎬 Video ready to play!")

                // Send loaded event immediately WITHOUT duration
                // Duration will be sent separately once it's available
                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Sending 'loaded' event...")
                let loadedStart = Date().timeIntervalSince1970
                self.sendEvent("loaded")
                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ 'loaded' event sent (took \(String(format: "%.3f", Date().timeIntervalSince1970 - loadedStart))s)")

                // Get duration asynchronously to avoid blocking the main thread
                // Accessing item.duration can block while asset metadata loads
                print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Dispatching to BG to get duration...")
                DispatchQueue.global(qos: .userInitiated).async { [weak self, weak item, t0] in
                    print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] In BG thread, accessing item.duration...")
                    guard let self = self, let item = item else { return }

                    let durStart = Date().timeIntervalSince1970
                    let duration = item.duration
                    print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅ item.duration accessed (took \(String(format: "%.3f", Date().timeIntervalSince1970 - durStart))s)")
                    let durationSeconds = CMTimeGetSeconds(duration)

                    // Send duration update event if valid
                    // MUST send on main thread - Flutter requires all channel messages on main thread
                    if durationSeconds.isFinite && !durationSeconds.isNaN {
                        let totalDuration = Int(durationSeconds * 1000) // milliseconds
                        print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] Duration: \(totalDuration)ms, dispatching to MAIN to send event...")
                        let mainDispatch2 = Date().timeIntervalSince1970
                        DispatchQueue.main.async {
                            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ▶️ ON MAIN - sending durationChanged (dispatch lag: \(String(format: "%.3f", Date().timeIntervalSince1970 - mainDispatch2))s)...")
                            let sendStart = Date().timeIntervalSince1970
                            self.sendEvent("durationChanged", data: [
                                "duration": totalDuration
                            ])
                            print("⏱️ [T+\(String(format: "%.3f", Date().timeIntervalSince1970 - t0))s] ✅✅ durationChanged sent (took \(String(format: "%.3f", Date().timeIntervalSince1970 - sendStart))s)")
                        }
                    } else {
                        print("⚠️ Duration is not valid: \(durationSeconds)")
                    }
                }

                // Set up PiP controller if available
                if #available(iOS 14.0, *) {
                    if AVPictureInPictureController.isPictureInPictureSupported() {
                        print("🎬 PiP is supported on this device")
                        self.sendEvent("pipAvailabilityChanged", data: ["isAvailable": true])
                    } else {
                        print("🎬 PiP is NOT supported on this device")
                        self.sendEvent("pipAvailabilityChanged", data: ["isAvailable": false])
                    }
                } else {
                    self.sendEvent("pipAvailabilityChanged", data: ["isAvailable": false])
                }

                // Auto play if requested
                if autoPlay {
                    self.player?.play()
                }

                // Release observer (avoid leaks)
                statusObserver?.invalidate()

            case .failed:
                let error = item.error?.localizedDescription ?? "Unknown error"
                print("❌ Failed to load video: \(error)")
                self.sendEvent("error", data: ["message": error])
                statusObserver?.invalidate()

            case .unknown:
                break

            @unknown default:
                break
            }
        }
    }


    func handlePlay(result: @escaping FlutterResult) {
        // Activate audio session asynchronously to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setActive(true)
        }

        // Start playback IMMEDIATELY
        player?.play()

        // Apply the desired playback speed immediately
        player?.rate = desiredPlaybackSpeed
        print("Playing with speed: \(desiredPlaybackSpeed)")

        // Mark this view as the primary (active) view for this controller
        // This ensures automatic PiP will be enabled on THIS view, not other views
        if let controllerIdValue = controllerId {
            SharedPlayerManager.shared.setPrimaryView(viewId, for: controllerIdValue)
        }

        // Enable automatic PiP for this controller and disable for all others
        // Only if automatic PiP was requested in creation params
        if #available(iOS 14.2, *) {
            if let controllerIdValue = controllerId {
                // Only enable if the user requested it in creation params
                let shouldEnableAutoPiP = canStartPictureInPictureAutomatically
                if shouldEnableAutoPiP {
                    SharedPlayerManager.shared.setAutomaticPiPEnabled(for: controllerIdValue, enabled: true)
                } else {
                    print("🎬 Automatic PiP not enabled (canStartPictureInPictureAutomatically = false)")
                }
            }
        }

        // Play event will be sent automatically by timeControlStatus observer
        // Return result IMMEDIATELY - don't wait for Now Playing setup
        result(nil)

        // THEN set up Now Playing info asynchronously (completely non-blocking)
        // This ensures the play button responds instantly
        if let mediaInfo = currentMediaInfo {
            let title = mediaInfo["title"] ?? "Unknown"
            print("📱 Will set Now Playing info for: \(title)")

            // Set up Now Playing immediately in background
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.setupNowPlayingInfo(mediaInfo: mediaInfo)
            }
        } else {
            print("⚠️  No media info available when playing - media controls will not work correctly")
        }

        // Update Now Playing playback time asynchronously - don't block the UI
        // This accesses MPNowPlayingInfoCenter which can block on first access
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.updateNowPlayingPlaybackTime()
        }
    }

    func handlePause(result: @escaping FlutterResult) {
        player?.pause()

        // Disable automatic PiP when paused
        // This prevents automatic PiP from triggering for paused videos
        if #available(iOS 14.2, *) {
            if let controllerIdValue = controllerId, canStartPictureInPictureAutomatically {
                SharedPlayerManager.shared.setAutomaticPiPEnabled(for: controllerIdValue, enabled: false)
            }
        }

        // Pause event will be sent automatically by timeControlStatus observer
        // Return result IMMEDIATELY
        result(nil)

        // Update Now Playing asynchronously - don't block the UI
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.updateNowPlayingPlaybackTime()
        }
    }

    func handleSeekTo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any],
           let milliseconds = args["milliseconds"] as? Int {
            let seconds = Double(milliseconds) / 1000.0
            player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000)) { [weak self] _ in
                self?.sendEvent("seek", data: ["position": milliseconds])

                // Update Now Playing asynchronously
                DispatchQueue.global(qos: .utility).async {
                    self?.updateNowPlayingPlaybackTime()
                }
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
            print("Setting playback speed to: \(speed)")

            // Store the desired speed
            desiredPlaybackSpeed = Float(speed)

            print("Player status: \(player?.timeControlStatus.rawValue ?? -1)")

            // If currently playing, apply the speed immediately
            if player?.timeControlStatus == .playing {
                print("Player is playing, applying speed immediately")
                player?.rate = Float(speed)
            } else {
                print("Player is not playing, speed will be applied on next play")
            }

            sendEvent("speedChange", data: ["speed": speed])
            result(nil)
        } else {
            result(FlutterError(code: "INVALID_SPEED", message: "Invalid speed value", details: nil))
        }
    }

    func handleSetLooping(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any],
           let looping = args["looping"] as? Bool {
            print("Setting looping to: \(looping)")

            // Update the enableLooping property
            enableLooping = looping

            result(nil)
        } else {
            result(FlutterError(code: "INVALID_LOOPING", message: "Invalid looping value", details: nil))
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

    func handleSetShowNativeControls(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let show = arguments["show"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }

        // Set controls visibility for embedded player
        playerViewController.showsPlaybackControls = show

        // Also set for fullscreen player if it exists
        if let fullscreenVC = fullscreenPlayerViewController {
            fullscreenVC.showsPlaybackControls = show
        }

        result(nil)
    }

    func handleIsAirPlayAvailable(result: @escaping FlutterResult) {
        // Check if AirPlay is supported on this device
        // AVRoutePickerView requires iOS 11.0+
        if #available(iOS 11.0, *) {
            // AirPlay is available on iOS 11.0+
            // Note: This checks if the device supports AirPlay, not if AirPlay devices
            // are currently available on the network (which changes dynamically)
            result(true)
        } else {
            // AirPlay requires iOS 11.0+
            result(false)
        }
    }

    func handleShowAirPlayPicker(result: @escaping FlutterResult) {
        // Check iOS version - AVRoutePickerView requires iOS 11.0+
        guard #available(iOS 11.0, *) else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "AirPlay picker requires iOS 11.0+", details: nil))
            return
        }

        // Find the root view controller
        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Could not find root view controller", details: nil))
            return
        }

        // Create an AVRoutePickerView
        let routePickerView = AVRoutePickerView()
        routePickerView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        routePickerView.isHidden = true

        // Add it temporarily to the view hierarchy
        rootViewController.view.addSubview(routePickerView)

        // Find the button inside the route picker view and simulate a tap
        DispatchQueue.main.async {
            for subview in routePickerView.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .touchUpInside)
                    break
                }
            }

            // Clean up - remove the route picker after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                routePickerView.removeFromSuperview()
            }

            result(nil)
        }
    }

    func handleDispose(result: @escaping FlutterResult) {
        print("🗑️ [VideoPlayerMethodHandler] handleDispose called for controllerId: \(String(describing: controllerId))")

        // Pause the player first
        player?.pause()
        print("⏸️ [VideoPlayerMethodHandler] Player paused")

        // Clean up remote command ownership (transfer to another view if possible)
        cleanupRemoteCommandOwnership()

        // Remove from shared manager if this is a shared player
        if let controllerId = controllerId {
            print("🔄 [VideoPlayerMethodHandler] Calling SharedPlayerManager.removePlayer for controllerId: \(controllerId)")
            SharedPlayerManager.shared.removePlayer(for: controllerId)
            print("✅ [VideoPlayerMethodHandler] SharedPlayerManager.removePlayer completed for controllerId: \(controllerId)")
        } else {
            print("⚠️ [VideoPlayerMethodHandler] No controllerId - cannot remove from SharedPlayerManager")
        }

        // Clear local player reference
        player = nil
        print("🧹 [VideoPlayerMethodHandler] Local player reference cleared")

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
        // Store the playback state before dismissing
        let wasPlaying = player?.rate != 0
        
        // Dismiss the fullscreen player view controller if it exists
        if let fullscreenVC = fullscreenPlayerViewController {
            fullscreenVC.dismiss(animated: true) {
                // Clear the reference
                self.fullscreenPlayerViewController = nil
                
                // Resume playback if it was playing before
                if wasPlaying {
                    self.player?.play()
                }

                self.sendEvent("fullscreenChange", data: ["isFullscreen": false])
                result(nil)
            }
        } else {
            // Fallback: dismiss the embedded player controller (shouldn't happen)
            playerViewController.dismiss(animated: true) {
                // Resume playback if it was playing before
                if wasPlaying {
                    self.player?.play()
                }
                
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
            // Check if video is loaded and ready
            guard let player = player, let currentItem = player.currentItem else {
                print("❌ No video loaded for PiP")
                result(FlutterError(code: "NO_VIDEO", message: "No video loaded.", details: nil))
                return
            }
            
            guard currentItem.status == .readyToPlay else {
                print("❌ Video not ready for PiP")
                result(FlutterError(code: "NOT_READY", message: "Video is not ready to play.", details: nil))
                return
            }
            
            // Check if PiP is supported and allowed
            guard playerViewController.allowsPictureInPicturePlayback else {
                print("❌ PiP not allowed on player view controller")
                result(FlutterError(code: "NOT_ALLOWED", message: "Picture-in-Picture is not allowed.", details: nil))
                return
            }
            
            guard AVPictureInPictureController.isPictureInPictureSupported() else {
                print("❌ PiP not supported on this device")
                result(FlutterError(code: "NOT_SUPPORTED", message: "Picture-in-Picture is not supported on this device.", details: nil))
                return
            }
            
            print("🎬 Starting manual PiP")
            
            // Create PiP controller only for manual entry
            // This is separate from automatic PiP which is handled by AVPlayerViewController
            if pipController == nil {
                if let playerLayer = findPlayerLayer() {
                    pipController = try? AVPictureInPictureController(playerLayer: playerLayer)
                    pipController?.delegate = self
                    print("✅ Created PiP controller for manual entry")
                } else {
                    print("❌ Could not find player layer")
                    result(FlutterError(code: "NO_LAYER", message: "Could not find player layer", details: nil))
                    return
                }
            }
            
            // Wait a moment for the controller to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else {
                    result(FlutterError(code: "DISPOSED", message: "View was disposed", details: nil))
                    return
                }
                
                if let pipController = self.pipController {
                    if pipController.isPictureInPicturePossible {
                        print("🎬 Starting PiP now")
                        pipController.startPictureInPicture()
                        result(true)
                    } else {
                        print("❌ PiP not possible at this time")
                        result(FlutterError(code: "PIP_NOT_POSSIBLE", message: "Picture-in-Picture is not possible at this time. Make sure the video is playing.", details: nil))
                    }
                } else {
                    print("❌ PiP controller not available")
                    result(FlutterError(code: "NO_CONTROLLER", message: "PiP controller not available", details: nil))
                }
            }
        } else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "PiP requires iOS 14.0+", details: nil))
        }
    }
    
    /// Finds the AVPlayerLayer in the view hierarchy
    private func findPlayerLayer() -> AVPlayerLayer? {
        // Get the player layer from the AVPlayerViewController's view
        if let playerView = playerViewController.view {
            return findPlayerLayerInView(playerView)
        }
        return nil
    }
    
    /// Recursively searches for AVPlayerLayer in view hierarchy
    private func findPlayerLayerInView(_ view: UIView) -> AVPlayerLayer? {
        // Check if this view's layer is an AVPlayerLayer
        if let playerLayer = view.layer as? AVPlayerLayer {
            return playerLayer
        }
        
        // Check sublayers
        if let sublayers = view.layer.sublayers {
            for sublayer in sublayers {
                if let playerLayer = sublayer as? AVPlayerLayer {
                    return playerLayer
                }
            }
        }
        
        // Recursively check subviews
        for subview in view.subviews {
            if let playerLayer = findPlayerLayerInView(subview) {
                return playerLayer
            }
        }
        
        return nil
    }
    

    func handleExitPictureInPicture(result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            if let pipController = pipController {
                if pipController.isPictureInPictureActive {
                    pipController.stopPictureInPicture()
                    result(true)
                } else {
                    result(false)
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

            // Check if currently buffering
            let isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate

            // Only send event if values are valid (not NaN or Infinity)
            if positionSeconds.isFinite && !positionSeconds.isNaN &&
               durationSeconds.isFinite && !durationSeconds.isNaN && durationSeconds > 0 {
                let position = Int(positionSeconds * 1000) // milliseconds
                let totalDuration = Int(durationSeconds * 1000) // milliseconds
                let bufferedPosition = Int(bufferedSeconds * 1000) // milliseconds

                self.sendEvent("timeUpdate", data: [
                    "position": position,
                    "duration": totalDuration,
                    "bufferedPosition": bufferedPosition,
                    "isBuffering": isBuffering
                ])
            }
        }
    }

    /// Determines if a URL is an HLS stream
    /// Checks for .m3u8 extension or common HLS patterns
    private func isHlsUrl(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()

        // Check for .m3u8 extension (most reliable indicator)
        if urlString.contains(".m3u8") {
            return true
        }

        // Check for /hls/ as a path segment (not substring to avoid false positives like "english")
        if urlString.range(of: "/hls/", options: .regularExpression) != nil {
            return true
        }

        // Check for manifest in path
        if urlString.contains("manifest.m3u8") {
            return true
        }

        return false
    }
}
