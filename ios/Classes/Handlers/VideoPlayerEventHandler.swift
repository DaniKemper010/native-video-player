import Flutter
import AVFoundation

extension VideoPlayerView {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        // Send initial events now that the EventChannel is connected
        sendEvent("isInitialized")

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}