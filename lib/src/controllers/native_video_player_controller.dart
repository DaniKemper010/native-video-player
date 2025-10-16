import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../enums/native_video_player_event.dart';
import '../models/native_video_player_media_info.dart';
import '../models/native_video_player_quality.dart';

/// Controller for managing native iOS video player via platform channels
///
/// This controller bridges Flutter and native iOS AVPlayerViewController using
/// MethodChannel for commands and EventChannel for state updates. State is managed
/// through Riverpod providers for reactive UI updates.
///
/// **Usage:**
/// ```dart
/// final controller = NativeVideoPlayerController(
///   ref: ref,
///   id: videoId,
///   autoPlay: true,
/// );
/// await controller.load(platformViewId: platformViewId, url: 'https://example.com/video.m3u8');
/// ```
///
/// **State Access:**
/// Access state through instance providers:
/// - `controller.nativeVideoPlayerStateProvider` - Current player state
/// - `controller.nativeVideoPlayerIsPlayingProvider` - Is playing boolean
/// - `controller.nativeVideoPlayerErrorProvider` - Error message if any
///
/// **Platform Communication:**
/// - MethodChannel: Flutter → Native (play, pause, seek, etc.)
/// - EventChannel: Native → Flutter (state changes, errors, buffering)
class NativeVideoPlayerController {
  NativeVideoPlayerController({
    required this.id,
    this.autoPlay = false,
    this.mediaInfo,
    this.allowsPictureInPicture = true,
    this.canStartPictureInPictureAutomatically = true,
    this.showNativeControls = true,
  });

  /// Initialize the controller and wait for the platform view to be created
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Create a completer that will be completed when the platform view is created
    _initializeCompleter = Completer<void>();

    // Wait for the platform view to be created
    await _initializeCompleter!.future;

    _isInitialized = true;
  }

  /// Unique identifier for this video player instance
  final int id;

  /// Whether to start playing automatically when initialized
  final bool autoPlay;

  /// Optional media information (title, subtitle, artwork) for Now Playing display
  final NativeVideoPlayerMediaInfo? mediaInfo;

  /// Whether Picture-in-Picture mode is allowed
  final bool allowsPictureInPicture;

  /// Whether PiP can start automatically when app goes to background (iOS 14.2+)
  final bool canStartPictureInPictureAutomatically;

  /// Whether to show the native video player controls
  final bool showNativeControls;

  /// Internal list of available video qualities (HLS variants)
  List<NativeVideoPlayerQuality> _qualities = <NativeVideoPlayerQuality>[];

  /// Available video qualities (HLS variants)
  List<NativeVideoPlayerQuality> get qualities => _qualities;

  /// Whether the video is currently in fullscreen mode
  bool _isFullScreen = false;

  /// Method channel for sending commands to native side (play, pause, seek, etc.)
  /// Uses a shared channel name based on the controller ID
  MethodChannel? _methodChannel;

  /// Whether the controller has been initialized
  bool _isInitialized = false;

  /// Whether the controller has been loaded and is ready to use
  bool _isLoaded = false;

  /// Video URL set when load() is called
  String? _url;

  /// Set of platform view IDs that are using this controller
  final Set<int> _platformViewIds = <int>{};

  /// Primary platform view ID (first one registered)
  int? _primaryPlatformViewId;

  /// Completer to wait for initialization to complete
  Completer<void>? _initializeCompleter;

  /// Event channel subscriptions for each platform view
  final Map<int, StreamSubscription<dynamic>> _eventSubscriptions = <int, StreamSubscription<dynamic>>{};

  /// Event handlers for video player events (supports multiple listeners)
  final List<void Function(NativeVideoPlayerEvent)> _eventHandlers = <void Function(NativeVideoPlayerEvent)>[];

  /// Adds a listener for video player events
  void addListener(void Function(NativeVideoPlayerEvent) listener) {
    if (!_eventHandlers.contains(listener)) {
      _eventHandlers.add(listener);
    }
  }

  /// Removes a listener for video player events
  void removeListener(void Function(NativeVideoPlayerEvent) listener) => _eventHandlers.remove(listener);

  /// Whether the controller is loaded and ready to accept commands
  bool get isLoaded => _isLoaded;

  /// Video URL to play (supports HLS .m3u8 and direct video URLs)
  /// Returns null if load() has not been called yet
  String? get url => _url;

  /// Parameters passed to native side when creating the platform view
  /// Includes controller ID, autoPlay, PiP settings, media info, and fullscreen state
  Map<String, dynamic> get creationParams => <String, dynamic>{
    'controllerId': id,
    'autoPlay': autoPlay,
    'allowsPictureInPicture': allowsPictureInPicture,
    'canStartPictureInPictureAutomatically': canStartPictureInPictureAutomatically,
    'showNativeControls': showNativeControls,
    'isFullScreen': _isFullScreen,
    if (mediaInfo != null) 'mediaInfo': mediaInfo!.toMap(),
  };

  /// Called when a native platform view is created
  ///
  /// Multiple platform views can register with the same controller.
  /// Each platform view gets its own event channel listener to receive events.
  /// The first platform view becomes the primary view that handles method channel communication.
  ///
  /// **Parameters:**
  /// - platformViewId: The unique ID assigned by Flutter to the platform view
  Future<void> onPlatformViewCreated(int platformViewId, BuildContext context) async {
    _platformViewIds.add(platformViewId);

    // Set up method channel only once (for the first platform view)
    if (_primaryPlatformViewId == null) {
      _primaryPlatformViewId = platformViewId;
      _methodChannel = const MethodChannel('native_video_player');
    }

    // IMPORTANT: Set up event channel for EVERY platform view
    // This ensures that both the original and fullscreen widgets receive events
    final EventChannel eventChannel = EventChannel('native_video_player_$platformViewId');

    // Set up event stream and store the subscription for later cleanup
    _eventSubscriptions[platformViewId] = eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => NativeVideoPlayerEvent.fromMap(event as Map<dynamic, dynamic>))
        .listen(
          (NativeVideoPlayerEvent event) async {
            // Complete initialization when we receive the isInitialized event
            if (!_isInitialized && event.type == NativeVideoPlayerEventType.isInitialized) {
              _initializeCompleter?.complete();
            }

            // Handle fullscreen change events from native
            if (event.type == NativeVideoPlayerEventType.fullscreenChange) {
              final bool isFullscreen = event.data?['isFullscreen'] as bool;
              // Just update internal state, don't call native methods back
              _isFullScreen = isFullscreen;
            }

            // Notify all listeners
            for (final void Function(NativeVideoPlayerEvent) handler in _eventHandlers) {
              handler(event);
            }
          },
          onError: (dynamic error) {
            if (!_isInitialized) {
              _initializeCompleter?.completeError(error);
            }
          },
        );
  }

  /// Called when a platform view is disposed
  ///
  /// Unregisters the platform view from this controller.
  /// If it was the primary view, promotes another view to primary.
  ///
  /// **Parameters:**
  /// - platformViewId: The ID of the platform view being disposed
  void onPlatformViewDisposed(int platformViewId) {
    _platformViewIds.remove(platformViewId);

    // Cancel the event channel subscription for this platform view
    unawaited(_eventSubscriptions[platformViewId]?.cancel() ?? Future<void>.value());
    _eventSubscriptions.remove(platformViewId);

    // If the primary view was disposed, promote another view to primary
    if (_primaryPlatformViewId == platformViewId) {
      _primaryPlatformViewId = null;

      // If there are other views, we need to reinitialize with a new primary
      if (_platformViewIds.isNotEmpty) {
        // Mark as needing reinitialization for the next view
        _isInitialized = false;
        _isLoaded = false;
        _methodChannel = null;
      }
    }
  }

  /// Loads a video URL into the already initialized player
  ///
  /// Must be called after the platform view is created and channels are set up.
  /// This method loads the video URL on the native side and fetches available qualities.
  /// If multiple platform views are using this controller, they will all sync to the same video.
  ///
  /// **Parameters:**
  /// - url: Video URL to play (supports HLS .m3u8 and direct video URLs)
  /// - headers: Optional HTTP headers to include with the video request (e.g., {"Referer": "domain"})
  ///
  /// **Returns:**
  /// A Future that completes when the video is loaded
  Future<void> load({required String url, Map<String, String>? headers}) async {
    if (_isLoaded) {
      return;
    }

    if (!_isInitialized) {
      throw Exception('Controller not initialized. Call initialize() first.');
    }

    if (_methodChannel == null || _primaryPlatformViewId == null) {
      throw Exception('Method channel not initialized. Platform view not created.');
    }

    _url = url;

    try {
      // Load the video URL on the native side with autoPlay setting
      final Map<String, Object> params = <String, Object>{
        'url': url,
        'autoPlay': autoPlay,
        'viewId': _primaryPlatformViewId!,
      };

      if (headers != null) {
        params['headers'] = headers;
      }

      if (mediaInfo != null) {
        params['mediaInfo'] = mediaInfo!.toMap();
      }

      await _methodChannel!.invokeMethod<void>('load', params);

      // Fetch available qualities after loading
      await _fetchAvailableQualities();

      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading video: $e');
      rethrow;
    }
  }

  /// Starts or resumes video playback
  Future<void> play() async {
    if (_methodChannel == null) {
      return;
    }
    try {
      await _methodChannel!.invokeMethod<void>('play');
    } catch (e) {
      debugPrint('Error calling play: $e');
    }
  }

  Future<void> pause() async {
    if (_methodChannel == null) {
      return;
    }
    try {
      await _methodChannel!.invokeMethod<void>('pause');
    } catch (e) {
      debugPrint('Error calling pause: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_methodChannel == null) {
      return;
    }
    try {
      await _methodChannel!.invokeMethod<void>('seekTo', position.inMilliseconds);
    } catch (e) {
      debugPrint('Error calling seekTo: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    if (_methodChannel == null) {
      return;
    }
    try {
      await _methodChannel!.invokeMethod<void>('setVolume', volume);
    } catch (e) {
      debugPrint('Error calling setVolume: $e');
    }
  }

  Future<void> setSpeed(double speed) async {
    if (_methodChannel == null) {
      return;
    }
    try {
      await _methodChannel!.invokeMethod<void>('setSpeed', speed);
    } catch (e) {
      debugPrint('Error calling setSpeed: $e');
    }
  }

  Future<void> setQuality(NativeVideoPlayerQuality quality) async {
    if (_methodChannel == null) {
      return;
    }
    try {
      await _methodChannel!.invokeMethod<void>('setQuality', quality.toMap());
    } catch (e) {
      debugPrint('Error calling setQuality: $e');
    }
  }

  Future<void> _fetchAvailableQualities() async {
    if (_methodChannel == null) {
      return;
    }
    try {
      final dynamic result = await _methodChannel!.invokeMethod<dynamic>('getAvailableQualities');
      if (result is List) {
        _qualities = result.map((dynamic e) => NativeVideoPlayerQuality.fromMap(e as Map<dynamic, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching qualities: $e');
    }
  }

  /// Returns whether the video is currently in fullscreen mode
  bool get isFullScreen => _isFullScreen;

  /// Enters fullscreen mode
  /// Triggers native fullscreen on both Android and iOS
  Future<void> enterFullScreen() async {
    if (_isFullScreen) {
      return;
    }

    _isFullScreen = true;

    // Call native method to enter fullscreen
    if (_methodChannel != null && _primaryPlatformViewId != null) {
      try {
        await _methodChannel!.invokeMethod<void>('enterFullScreen', <String, Object>{
          'viewId': _primaryPlatformViewId!,
        });
      } catch (e) {
        debugPrint('Error calling enterFullScreen: $e');
      }
    }
  }

  /// Exits fullscreen mode
  /// Triggers native fullscreen exit on both Android and iOS
  Future<void> exitFullScreen() async {
    if (!_isFullScreen) {
      return;
    }

    _isFullScreen = false;

    // Call native method to exit fullscreen
    if (_methodChannel != null && _primaryPlatformViewId != null) {
      try {
        await _methodChannel!.invokeMethod<void>('exitFullScreen', <String, Object>{
          'viewId': _primaryPlatformViewId!,
        });
      } catch (e) {
        debugPrint('Error calling exitFullScreen: $e');
      }
    }
  }

  /// Toggles fullscreen mode
  Future<void> toggleFullScreen() async {
    if (_isFullScreen) {
      await exitFullScreen();
    } else {
      await enterFullScreen();
    }
  }

  /// Disposes of resources and cleans up platform channels
  ///
  /// Should be called when the video player is no longer needed.
  /// The native player is automatically disposed when the platform view is destroyed.
  Future<void> dispose() async {
    // Exit fullscreen if active
    if (_isFullScreen) {
      await exitFullScreen();
    }

    // Cancel all event channel subscriptions
    for (final StreamSubscription<dynamic> subscription in _eventSubscriptions.values) {
      await subscription.cancel();
    }
    _eventSubscriptions.clear();

    _methodChannel = null;
    _isInitialized = false;
    _isLoaded = false;
    _url = null;
    _platformViewIds.clear();
    _primaryPlatformViewId = null;
    _initializeCompleter = null;
    _eventHandlers.clear();
  }
}
