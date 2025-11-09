import Flutter
import UIKit

@objc public class NativeVideoPlayerPlugin: NSObject, FlutterPlugin {
    private static var registeredViews: [Int64: VideoPlayerView] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        print("Registering NativeVideoPlayerPlugin")
        let factory = VideoPlayerViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "native_video_player")
        print("NativeVideoPlayerPlugin registered with id: native_video_player")

        // Pre-warm iOS network stack in the background to avoid 4.5s freeze on first video load
        // This triggers one-time network initialization (DNS, URLSession, certificate validation)
        // without blocking the UI
        DispatchQueue.global(qos: .utility).async {
            print("🌐 Pre-warming network stack...")
            let start = Date().timeIntervalSince1970

            // Use a lightweight, reliable URL for pre-warming
            // Google's generate_204 endpoint is designed for connectivity checks (returns empty response)
            if let url = URL(string: "https://www.google.com/generate_204") {
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD"  // HEAD request - no body download
                request.timeoutInterval = 5.0

                let task = URLSession.shared.dataTask(with: request) { _, response, error in
                    let elapsed = Date().timeIntervalSince1970 - start
                    if let error = error {
                        print("🌐 Network pre-warm completed with error in \(String(format: "%.3f", elapsed))s: \(error.localizedDescription)")
                    } else if let httpResponse = response as? HTTPURLResponse {
                        print("🌐 ✅ Network stack pre-warmed successfully in \(String(format: "%.3f", elapsed))s (HTTP \(httpResponse.statusCode))")
                    }
                }
                task.resume()
            }
        }

        // Register a method handler at the plugin level to forward calls to the appropriate view
        let channel = FlutterMethodChannel(name: "native_video_player", binaryMessenger: registrar.messenger())
        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            print("Plugin received method call: \(call.method)")
            if let args = call.arguments as? [String: Any],
               let viewId = args["viewId"] as? Int64,
               let view = registeredViews[viewId] {
                view.handleMethodCall(call: call, result: result)
            } else {
                result(FlutterError(code: "NO_VIEW", message: "No view found for method call", details: nil))
            }
        }

        // Register asset resolution channel
        let assetChannel = FlutterMethodChannel(name: "native_video_player/assets", binaryMessenger: registrar.messenger())
        assetChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "resolveAssetPath" {
                if let args = call.arguments as? [String: Any],
                   let assetKey = args["assetKey"] as? String {
                    // Flutter assets are bundled in the app's main bundle
                    let key = registrar.lookupKey(forAsset: assetKey)
                    if let path = Bundle.main.path(forResource: key, ofType: nil) {
                        print("Resolved asset '\(assetKey)' to '\(path)'")
                        result(path)
                    } else {
                        result(FlutterError(code: "ASSET_NOT_FOUND", message: "Asset not found: \(assetKey)", details: nil))
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Asset key is required", details: nil))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    public static func registerView(_ view: VideoPlayerView, withId viewId: Int64) {
        print("Registering view with id: \(viewId)")
        registeredViews[viewId] = view
    }
    
    public static func unregisterView(withId viewId: Int64) {
        print("Unregistering view with id: \(viewId)")
        registeredViews.removeValue(forKey: viewId)
    }
}

class VideoPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private var views: [Int64: VideoPlayerView] = [:]

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        print("VideoPlayerViewFactory creating view with id: \(viewId)")
        let view = VideoPlayerView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
        views[viewId] = view
        NativeVideoPlayerPlugin.registerView(view, withId: viewId)
        return view
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
