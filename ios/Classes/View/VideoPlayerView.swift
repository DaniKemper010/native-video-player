import Flutter
import UIKit
import AVKit
import AVFoundation
import QuartzCore

// MARK: - Main Video Player View

@objc public class VideoPlayerView: NSObject, FlutterPlatformView, FlutterStreamHandler {
    var playerViewController: AVPlayerViewController
    var player: AVPlayer?
    private var methodChannel: FlutterMethodChannel
    private var channelName: String
    var eventSink: FlutterEventSink?
    var availableQualities: [[String: Any]] = []
    var qualityLevels: [VideoPlayer.QualityLevel] = []
    var isAutoQuality = false
    var lastBitrateCheck: TimeInterval = 0
    let bitrateCheckInterval: TimeInterval = 5.0 // Check every 5 seconds
    var controllerId: Int?
    var pipController: AVPictureInPictureController?
    
    // Store the platform view ID for registration
    var viewId: Int64 = 0
    
    // Store whether automatic PiP was requested in creation params
    var canStartPictureInPictureAutomatically: Bool = true

    // Separate player view controller for fullscreen (prevents removing embedded view)
    var fullscreenPlayerViewController: AVPlayerViewController?

    // Store media info for Now Playing
    var currentMediaInfo: [String: Any]?
    var timeObserver: Any?

    // Track if this is a shared player (to avoid sending duplicate initialization events)
    var isSharedPlayer: Bool = false

    // AirPlay route detector
    var routeDetector: AVRouteDetector?

    // Store desired playback speed
    var desiredPlaybackSpeed: Float = 1.0

    public init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        print("Creating VideoPlayerView with id: \(viewId)")
        self.viewId = viewId
        channelName = "native_video_player_\(viewId)"
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: messenger
        )

        // Always create a new AVPlayerViewController for each platform view
        playerViewController = AVPlayerViewController()

        // Extract controller ID from args to get shared player
        if let args = args as? [String: Any],
           let controllerIdValue = args["controllerId"] as? Int {
            controllerId = controllerIdValue

            // Get or create shared player (but new view controller each time)
            let (sharedPlayer, alreadyExisted) = SharedPlayerManager.shared.getOrCreatePlayer(for: controllerIdValue)
            player = sharedPlayer
            isSharedPlayer = alreadyExisted

            if alreadyExisted {
                print("Using existing shared player for controller ID: \(controllerIdValue)")
            } else {
                print("Creating new shared player for controller ID: \(controllerIdValue)")
            }
        } else {
            // Fallback: create new instances if no controller ID provided
            print("No controller ID provided, creating new player")
            player = AVPlayer()
        }

        super.init()

        // Assign the shared player to this new view controller
        playerViewController.player = player

        // Configure playback controls
        let showControls = (args as? [String: Any])?["showNativeControls"] as? Bool ?? true
        playerViewController.showsPlaybackControls = showControls
        playerViewController.delegate = self

        // Disable automatic Now Playing updates - we'll handle it manually
        playerViewController.updatesNowPlayingInfoCenter = false

        // Extract configuration from Flutter args
        if let args = args as? [String: Any] {
            // PiP configuration from args
            let argsAllowsPiP = args["allowsPictureInPicture"] as? Bool ?? true
            let argsCanStartAutomatically = args["canStartPictureInPictureAutomatically"] as? Bool ?? true
            let argsShowNativeControls = args["showNativeControls"] as? Bool ?? true

            // For shared players, try to get PiP settings from SharedPlayerManager
            // This ensures PiP settings persist across all views using the same controller
            if let controllerIdValue = controllerId {
                if let sharedSettings = SharedPlayerManager.shared.getPipSettings(for: controllerIdValue) {
                    // Use existing shared settings
                    self.canStartPictureInPictureAutomatically = sharedSettings.canStartPictureInPictureAutomatically
                    playerViewController.allowsPictureInPicturePlayback = sharedSettings.allowsPictureInPicture
                    print("✅ Using shared PiP settings for controller \(controllerIdValue) - allows: \(sharedSettings.allowsPictureInPicture), autoStart: \(sharedSettings.canStartPictureInPictureAutomatically)")
                } else {
                    // First view for this controller - store the settings
                    self.canStartPictureInPictureAutomatically = argsCanStartAutomatically
                    playerViewController.allowsPictureInPicturePlayback = argsAllowsPiP
                    SharedPlayerManager.shared.setPipSettings(
                        for: controllerIdValue,
                        allowsPictureInPicture: argsAllowsPiP,
                        canStartPictureInPictureAutomatically: argsCanStartAutomatically,
                        showNativeControls: argsShowNativeControls
                    )
                    print("✅ Stored new PiP settings for controller \(controllerIdValue) - allows: \(argsAllowsPiP), autoStart: \(argsCanStartAutomatically)")
                }
            } else {
                // Non-shared player - use settings from args
                self.canStartPictureInPictureAutomatically = argsCanStartAutomatically
                playerViewController.allowsPictureInPicturePlayback = argsAllowsPiP
                print("✅ PiP settings for non-shared player - allows: \(argsAllowsPiP), autoStart: \(argsCanStartAutomatically)")
            }

            if #available(iOS 14.2, *) {
                // Start with automatic PiP DISABLED
                // It will be enabled when this specific player starts playing (if allowed)
                // This prevents conflicts when multiple players exist
                playerViewController.canStartPictureInPictureAutomaticallyFromInline = false
                print("✅ PiP configured, automatic PiP will be enabled on play if allowed")
            } else {
                print("⚠️ Automatic PiP requires iOS 14.2+, current device doesn't support it")
            }

            // Store media info if provided during initialization
            // This ensures we have the correct media info even for shared players
            if let mediaInfo = args["mediaInfo"] as? [String: Any] {
                currentMediaInfo = mediaInfo
                print("📱 Stored media info during init: \(mediaInfo["title"] ?? "Unknown")")
            }
        }
        
        // Register this view with the SharedPlayerManager
        if let controllerIdValue = controllerId {
            SharedPlayerManager.shared.registerVideoPlayerView(self, viewId: viewId)
            print("✅ Registered VideoPlayerView for controller \(controllerIdValue), viewId: \(viewId)")

            // If this controller is currently the one with automatic PiP enabled,
            // this new view should become the primary view and get automatic PiP
            if #available(iOS 14.2, *) {
                if SharedPlayerManager.shared.isControllerActiveForAutoPiP(controllerIdValue) {
                    print("🎬 This controller is currently active for auto PiP")
                    if canStartPictureInPictureAutomatically {
                        // Set this new view as the primary view
                        SharedPlayerManager.shared.setPrimaryView(viewId, for: controllerIdValue)
                        // Re-apply automatic PiP settings to enable it on this new view
                        SharedPlayerManager.shared.setAutomaticPiPEnabled(for: controllerIdValue, enabled: true)
                        print("   → Set new view as primary and enabled automatic PiP (viewId: \(viewId))")
                    }
                }
            }
        }

        // Background audio setup - required for automatic PiP
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            print("✅ AVAudioSession configured for playback")
        } catch {
            print("❌ Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
        try? AVAudioSession.sharedInstance().setActive(true)

        print("Setting up method channel: \(channelName)")
        // Set up method call handler
        print("Setting method handler for channel: \(channelName)")
        methodChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else {
                result(FlutterError(code: "DISPOSED", message: "VideoPlayerView was disposed", details: nil))
                return
            }
            print("[\(self.channelName)] Received method call: \(call.method)")
            self.handleMethodCall(call: call, result: result)
        })
        
        // Set up event channel
        let eventChannel = FlutterEventChannel(
            name: "native_video_player_\(viewId)",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(self)

        // Set up observers for shared players if there's already a loaded video
        // The initial state event will be sent when onListen is called
        if isSharedPlayer, let currentItem = player?.currentItem {
            addObservers(to: currentItem)
            // Also set up periodic time observer for this new view
            setupPeriodicTimeObserver()
        }

        // Set up AirPlay route detector (iOS 11.0+)
        if #available(iOS 11.0, *) {
            setupAirPlayRouteDetector()
        }
    }

    public func view() -> UIView {
        return playerViewController.view
    }

    public func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("Handling method call: \(call.method) on channel: \(channelName)")
        switch call.method {
        case "load":
            handleLoad(call: call, result: result)
        case "play":
            handlePlay(result: result)
        case "pause":
            handlePause(result: result)
        case "seekTo":
            handleSeekTo(call: call, result: result)
        case "setVolume":
            handleSetVolume(call: call, result: result)
        case "setSpeed":
            handleSetSpeed(call: call, result: result)
        case "setQuality":
            handleSetQuality(call: call, result: result)
        case "getAvailableQualities":
            result(availableQualities)
        case "enterFullScreen":
            handleEnterFullScreen(result: result)
        case "exitFullScreen":
            handleExitFullScreen(result: result)
        case "isPictureInPictureAvailable":
            handleIsPictureInPictureAvailable(result: result)
        case "enterPictureInPicture":
            handleEnterPictureInPicture(result: result)
        case "exitPictureInPicture":
            handleExitPictureInPicture(result: result)
        case "setShowNativeControls":
            handleSetShowNativeControls(call: call, result: result)
        case "isAirPlayAvailable":
            handleIsAirPlayAvailable(result: result)
        case "showAirPlayPicker":
            handleShowAirPlayPicker(result: result)
        case "dispose":
            handleDispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func sendEvent(_ name: String, data: [String: Any]? = nil) {
        var event: [String: Any] = ["event": name]
        if let data = data {
            event.merge(data) { (_, new) in
                new
            }
        }
        eventSink?(event)
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("[\(channelName)] Event channel listener attached")
        self.eventSink = events

        // Send initial state event when listener is attached
        if isSharedPlayer {
            // For shared players, only send current playback state and position
            if let player = player, let currentItem = player.currentItem {
                let currentTimeSeconds = CMTimeGetSeconds(player.currentTime())
                let durationSeconds = CMTimeGetSeconds(currentItem.duration)

                // Check for NaN or invalid times
                if currentTimeSeconds.isNaN || durationSeconds.isNaN {
                    print("[\(channelName)] Skipping timeUpdated event — invalid currentTime or duration")
                } else {
                    let duration = Int(durationSeconds * 1000)
                    let position = Int(currentTimeSeconds * 1000)
                    sendEvent("timeUpdated", data: ["position": position, "duration": duration])
                }

                // Send current playback state
                switch player.timeControlStatus {
                case .playing:
                    print("[\(channelName)] Sending play event to new listener")
                    sendEvent("play")
                case .paused:
                    print("[\(channelName)] Sending pause event to new listener")
                    sendEvent("pause")
                case .waitingToPlayAtSpecifiedRate:
                    print("[\(channelName)] Sending buffering event to new listener")
                    sendEvent("buffering")
                @unknown default:
                    break
                }
            }

        } else {
            // For new players, send isInitialized event
            print("[\(channelName)] Sending isInitialized event to new listener")
            sendEvent("isInitialized")
        }

        // Send initial AirPlay availability state
        if #available(iOS 11.0, *) {
            if let detector = routeDetector {
                let isAvailable = detector.multipleRoutesDetected
                print("[\(channelName)] Sending initial AirPlay availability: \(isAvailable)")
                sendEvent("airPlayAvailabilityChanged", data: ["isAvailable": isAvailable])
            }
        }

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("[\(channelName)] Event channel listener detached")
        self.eventSink = nil
        return nil
    }

    deinit {
        print("VideoPlayerView deinit for channel: \(channelName), viewId: \(viewId)")
        
        // Unregister this view from SharedPlayerManager
        SharedPlayerManager.shared.unregisterVideoPlayerView(viewId: viewId)

        // Remove periodic time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        // Only remove observers, don't dispose the player if it's shared
        // The shared player will be kept alive for reuse
        if let item = player?.currentItem {
            item.removeObserver(self, forKeyPath: "status")
            item.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            item.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        }

        // Remove player observer for timeControlStatus
        player?.removeObserver(self, forKeyPath: "timeControlStatus")

        // Remove player observer for externalPlaybackActive
        player?.removeObserver(self, forKeyPath: "externalPlaybackActive")

        // Remove route detector observer
        if #available(iOS 11.0, *) {
            routeDetector?.removeObserver(self, forKeyPath: "multipleRoutesDetected")
            routeDetector?.isRouteDetectionEnabled = false
            routeDetector = nil
        }

        NotificationCenter.default.removeObserver(self)
        methodChannel.setMethodCallHandler(nil)

        // Note: player and playerViewController are NOT disposed here
        // They remain in SharedPlayerManager for reuse
        print("Platform view disposed but player kept alive for controller ID: \(String(describing: controllerId))")
    }
}

