import AVFoundation
import Foundation

extension VideoPlayerView {
    func addObservers(to item: AVPlayerItem) {
        item.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
        item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.new], context: nil)
        item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.new], context: nil)

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
        guard let item = object as? AVPlayerItem else {
            return
        }

        switch keyPath {
        case "status":
            switch item.status {
            case .readyToPlay:
                sendEvent("isInitialized")
            case .failed:
                sendEvent("error", data: ["message": item.error?.localizedDescription ?? "Unknown"])
            default: break
            }
        case "playbackBufferEmpty":
            if item.isPlaybackBufferEmpty {
                sendEvent("buffering")
            }
        case "playbackLikelyToKeepUp":
            if item.isPlaybackLikelyToKeepUp {
                sendEvent("loading")
            }
        default: break
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