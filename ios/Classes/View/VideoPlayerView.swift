import Flutter
import UIKit
import AVKit
import AVFoundation

// MARK: - Main Video Player View

@objc public class VideoPlayerView: NSObject, FlutterPlatformView, FlutterStreamHandler {
    var playerViewController: AVPlayerViewController
    var player: AVPlayer?
    private var methodChannel: FlutterMethodChannel
    private var channelName: String
    var eventSink: FlutterEventSink?
    var availableQualities: [[String: String]] = []
    var controllerId: Int?

    // Store media info for Now Playing
    var currentMediaInfo: [String: Any]?
    var timeObserver: Any?

    public init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        print("Creating VideoPlayerView with id: \(viewId)")
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
            print("Using shared player for controller ID: \(controllerIdValue)")

            // Get or create shared player (but new view controller each time)
            player = SharedPlayerManager.shared.getOrCreatePlayer(for: controllerIdValue)
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
            // PiP configuration
            let allowsPiP = args["allowsPictureInPicture"] as? Bool ?? true
            let canStartAutomatically = args["canStartPictureInPictureAutomatically"] as? Bool ?? true

            playerViewController.allowsPictureInPicturePlayback = allowsPiP
            if #available(iOS 14.2, *) {
                playerViewController.canStartPictureInPictureAutomaticallyFromInline = canStartAutomatically
            }
        }

        // Background audio setup
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
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
        
        // Send initialization event to signal that everything is set up
        sendEvent("isInitialized")
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

    deinit {
        print("VideoPlayerView deinit for channel: \(channelName)")

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
        NotificationCenter.default.removeObserver(self)
        methodChannel.setMethodCallHandler(nil)

        // Note: player and playerViewController are NOT disposed here
        // They remain in SharedPlayerManager for reuse
        print("Platform view disposed but player kept alive for controller ID: \(String(describing: controllerId))")
    }
}

