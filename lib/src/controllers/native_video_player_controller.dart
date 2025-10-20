import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../enums/native_video_player_event.dart';
import '../models/native_video_player_media_info.dart';
import '../models/native_video_player_quality.dart';
import '../models/native_video_player_state.dart';
import '../platform/video_player_method_channel.dart';

/// Controller for managing native video player via platform channels
///
/// This controller bridges Flutter and native AVPlayerViewController using
/// MethodChannel for commands and EventChannel for state updates.
///
/// **Usage:**
/// ```dart
/// final controller = NativeVideoPlayerController(
///   id: videoId,
///   autoPlay: true,
/// );
/// await controller.load(url: 'https://example.com/video.m3u8');
/// ```
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
    if (_state.activityState.isInitialized) {
      return;
    }

    // Create a completer that will be completed when the platform view is created
    _initializeCompleter = Completer<void>();

    // Wait for the platform view to be created
    await _initializeCompleter!.future;

    _updateState(_state.copyWith(activityState: PlayerActivityState.initialized));
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

  /// Current state of the video player
  NativeVideoPlayerState _state = const NativeVideoPlayerState();

  /// Video URL set when load() is called
  String? _url;

  /// Method channel wrapper for platform communication
  VideoPlayerMethodChannel? _methodChannel;

  /// Set of platform view IDs that are using this controller
  final Set<int> _platformViewIds = <int>{};

  /// Primary platform view ID (first one registered)
  int? _primaryPlatformViewId;

  /// Completer to wait for initialization to complete
  Completer<void>? _initializeCompleter;

  /// Event channel subscriptions for each platform view
  final Map<int, StreamSubscription<dynamic>> _eventSubscriptions = <int, StreamSubscription<dynamic>>{};

  /// MainActivity PiP event channel subscription (Android only)
  StreamSubscription<dynamic>? _pipEventSubscription;

  /// MainActivity PiP event channel subscription (Android only)
  StreamSubscription<dynamic>? get pipEventSubscription => _pipEventSubscription;

  /// Whether the MainActivity PiP event listener has been set up
  static bool _pipEventListenerSetup = false;

  /// Activity event handlers (play, pause, buffering, etc.)
  final List<void Function(PlayerActivityEvent)> _activityEventHandlers = <void Function(PlayerActivityEvent)>[];

  /// Control event handlers (quality, speed, pip, fullscreen, etc.)
  final List<void Function(PlayerControlEvent)> _controlEventHandlers = <void Function(PlayerControlEvent)>[];

  /// Updates the internal state
  void _updateState(NativeVideoPlayerState newState) => _state = newState;

  /// Adds a listener for activity events (play, pause, buffering, etc.)
  void addActivityListener(void Function(PlayerActivityEvent) listener) {
    if (!_activityEventHandlers.contains(listener)) {
      _activityEventHandlers.add(listener);
    }
  }

  /// Removes a listener for activity events
  void removeActivityListener(void Function(PlayerActivityEvent) listener) => _activityEventHandlers.remove(listener);

  /// Adds a listener for control events (quality, speed, pip, fullscreen, etc.)
  void addControlListener(void Function(PlayerControlEvent) listener) {
    if (!_controlEventHandlers.contains(listener)) {
      _controlEventHandlers.add(listener);
    }
  }

  /// Removes a listener for control events
  void removeControlListener(void Function(PlayerControlEvent) listener) => _controlEventHandlers.remove(listener);

  /// Video URL to play (supports HLS .m3u8 and direct video URLs)
  /// Returns null if load() has not been called yet
  String? get url => _url;

  /// Available video qualities (HLS variants)
  List<NativeVideoPlayerQuality> get qualities => _state.qualities;

  /// Returns whether the video is currently in fullscreen mode
  bool get isFullScreen => _state.isFullScreen;

  /// Returns the current playback position as a Duration
  Duration get currentPosition => _state.currentPosition;

  /// Returns the total video duration as a Duration
  Duration get duration => _state.duration;

  /// Returns the buffered position as a Duration (how far the video has been buffered)
  Duration get bufferedPosition => _state.bufferedPosition;

  /// Returns the current volume (0.0 to 1.0)
  double get volume => _state.volume;

  /// Returns the current activity state (playing, paused, buffering, etc.)
  PlayerActivityState get activityState => _state.activityState;

  /// Returns the current control state (quality change, pip, fullscreen, etc.)
  PlayerControlState get controlState => _state.controlState;

  /// Current player state
  NativeVideoPlayerState get state => _state;

  /// Parameters passed to native side when creating the platform view
  /// Includes controller ID, autoPlay, PiP settings, media info, and fullscreen state
  Map<String, dynamic> get creationParams => <String, dynamic>{
    'controllerId': id,
    'autoPlay': autoPlay,
    'allowsPictureInPicture': allowsPictureInPicture,
    'canStartPictureInPictureAutomatically': canStartPictureInPictureAutomatically,
    'showNativeControls': showNativeControls,
    'isFullScreen': _state.isFullScreen,
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
      _methodChannel = VideoPlayerMethodChannel(primaryPlatformViewId: platformViewId);
    }

    // IMPORTANT: Set up event channel for EVERY platform view
    // This ensures that both the original and fullscreen widgets receive events
    final EventChannel eventChannel = EventChannel('native_video_player_$platformViewId');

    // Set up event stream and store the subscription for later cleanup
    _eventSubscriptions[platformViewId] = eventChannel.receiveBroadcastStream().listen(
      (dynamic eventMap) async {
        final map = eventMap as Map<dynamic, dynamic>;
        final String eventName = map['event'] as String;

        // Determine if this is an activity event or control event
        final isActivityEvent = _isActivityEvent(eventName);

        if (isActivityEvent) {
          final activityEvent = PlayerActivityEvent.fromMap(map);

          // Complete initialization when we receive the isInitialized event
          if (!_state.activityState.isInitialized &&
              activityEvent.state == PlayerActivityState.initialized &&
              _initializeCompleter != null &&
              !_initializeCompleter!.isCompleted) {
            _initializeCompleter!.complete();
          }

          // Update activity state
          _updateState(_state.copyWith(activityState: activityEvent.state));

          // Handle videoLoaded events to get initial duration
          if (activityEvent.state == PlayerActivityState.loaded) {
            if (activityEvent.data != null) {
              final int duration = (activityEvent.data!['duration'] as num?)?.toInt() ?? 0;
              _updateState(_state.copyWith(duration: Duration(milliseconds: duration)));
            }
          }

          // Notify activity listeners
          for (final handler in _activityEventHandlers) {
            handler(activityEvent);
          }
        } else {
          final controlEvent = PlayerControlEvent.fromMap(map);

          // Handle fullscreen change events
          if (controlEvent.state == PlayerControlState.fullscreenEntered ||
              controlEvent.state == PlayerControlState.fullscreenExited) {
            final bool isFullscreen =
                controlEvent.data?['isFullscreen'] as bool? ??
                controlEvent.state == PlayerControlState.fullscreenEntered;
            _updateState(_state.copyWith(isFullScreen: isFullscreen, controlState: controlEvent.state));
          }

          // Handle time update events
          if (controlEvent.state == PlayerControlState.timeUpdated) {
            if (controlEvent.data != null) {
              final int position = (controlEvent.data!['position'] as num?)?.toInt() ?? 0;
              final int duration = (controlEvent.data!['duration'] as num?)?.toInt() ?? 0;
              final int bufferedPosition = (controlEvent.data!['bufferedPosition'] as num?)?.toInt() ?? 0;

              _updateState(
                _state.copyWith(
                  currentPosition: Duration(milliseconds: position),
                  duration: Duration(milliseconds: duration),
                  bufferedPosition: Duration(milliseconds: bufferedPosition),
                  controlState: controlEvent.state,
                ),
              );
            }
          } else {
            // Update control state for other control events
            _updateState(_state.copyWith(controlState: controlEvent.state));
          }

          // Notify control listeners
          for (final handler in _controlEventHandlers) {
            handler(controlEvent);
          }
        }
      },
      onError: (dynamic error) {
        if (!_state.activityState.isInitialized && _initializeCompleter != null && !_initializeCompleter!.isCompleted) {
          _initializeCompleter!.completeError(error);
        }
      },
    );

    // Set up MainActivity PiP event listener (Android only, once per app)
    _setupMainActivityPipListener();
  }

  /// Sets up a global PiP event listener from MainActivity (Android only)
  ///
  /// This listener receives PiP enter/exit events from the MainActivity
  /// when the user presses the home button or exits PiP mode.
  /// Only set up once per app lifecycle.
  void _setupMainActivityPipListener() {
    if (_pipEventListenerSetup) {
      return;
    }

    try {
      final EventChannel pipEventChannel = const EventChannel('native_video_player_pip_events');
      _pipEventSubscription = pipEventChannel.receiveBroadcastStream().listen(
        (dynamic eventMap) {
          final map = eventMap as Map<dynamic, dynamic>;
          final String eventName = map['event'] as String;
          final bool isInPipMode = map['isInPictureInPictureMode'] as bool? ?? false;

          // Create a control event based on the MainActivity event
          final PlayerControlState state;
          if (eventName == 'pipStart') {
            state = PlayerControlState.pipStarted;
          } else if (eventName == 'pipStop') {
            state = PlayerControlState.pipStopped;
          } else {
            return;
          }

          final controlEvent = PlayerControlEvent(
            state: state,
            data: <String, dynamic>{'isPictureInPicture': isInPipMode, 'fromMainActivity': true},
          );

          // Update controller state
          _updateState(_state.copyWith(controlState: state));

          // Notify all control listeners
          for (final handler in _controlEventHandlers) {
            handler(controlEvent);
          }
        },
        onError: (dynamic error) {
          debugPrint('MainActivity PiP event channel error: $error');
        },
      );

      _pipEventListenerSetup = true;
    } catch (e) {
      // EventChannel not available (likely iOS)
      debugPrint('MainActivity PiP event channel not available (expected on iOS): $e');
    }
  }

  /// Determines if an event name is an activity event
  bool _isActivityEvent(String eventName) {
    switch (eventName) {
      case 'isInitialized':
      case 'videoLoaded':
      case 'play':
      case 'pause':
      case 'buffering':
      case 'loading':
      case 'completed':
      case 'stopped':
      case 'error':
        return true;
      default:
        return false;
    }
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
        _updateState(_state.copyWith(activityState: PlayerActivityState.idle));
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
    if (_state.activityState.isLoaded) {
      return;
    }

    if (!_state.activityState.isInitialized) {
      throw Exception('Controller not initialized. Call initialize() first.');
    }

    if (_methodChannel == null) {
      throw Exception('Method channel not initialized. Platform view not created.');
    }

    _url = url;

    try {
      await _methodChannel!.load(url: url, autoPlay: autoPlay, headers: headers, mediaInfo: mediaInfo?.toMap());

      // Fetch available qualities after loading
      final qualities = await _methodChannel!.getAvailableQualities();

      _updateState(_state.copyWith(qualities: qualities, activityState: PlayerActivityState.loaded));

      // Notify control listeners about available qualities
      if (qualities.isNotEmpty) {
        final qualityEvent = PlayerControlEvent(
          state: PlayerControlState.qualityChanged,
          data: {
            'qualities': qualities.map((q) => q.toMap()).toList(),
            if (qualities.isNotEmpty) 'quality': qualities.first.toMap(),
          },
        );

        for (final handler in _controlEventHandlers) {
          handler(qualityEvent);
        }
      }
    } catch (e) {
      debugPrint('Error loading video: $e');
      rethrow;
    }
  }

  /// Starts or resumes video playback
  Future<void> play() async {
    await _methodChannel?.play();
  }

  /// Pauses video playback
  Future<void> pause() async {
    await _methodChannel?.pause();
  }

  /// Seeks to a specific position
  Future<void> seekTo(Duration position) async {
    await _methodChannel?.seekTo(position);
  }

  /// Sets the volume
  Future<void> setVolume(double volume) async {
    await _methodChannel?.setVolume(volume);
    _updateState(_state.copyWith(volume: volume));
  }

  /// Sets the playback speed
  Future<void> setSpeed(double speed) async {
    await _methodChannel?.setSpeed(speed);
  }

  /// Sets the video quality
  Future<void> setQuality(NativeVideoPlayerQuality quality) async {
    await _methodChannel?.setQuality(quality);
  }

  /// Returns whether Picture-in-Picture is available on this device
  /// Checks the actual device capabilities rather than just the platform
  /// PiP is available on iOS 14+ and Android 8+ (if the device supports it)
  Future<bool> isPictureInPictureAvailable() async {
    if (_methodChannel == null) {
      return false;
    }
    return await _methodChannel!.isPictureInPictureAvailable();
  }

  /// Enters Picture-in-Picture mode
  /// Only works on iOS 14+ and Android 8+
  Future<bool> enterPictureInPicture() async {
    if (_methodChannel == null) {
      return false;
    }
    return await _methodChannel!.enterPictureInPicture();
  }

  /// Exits Picture-in-Picture mode
  /// Only works on iOS 14+ and Android 8+
  Future<bool> exitPictureInPicture() async {
    if (_methodChannel == null) {
      return false;
    }
    return await _methodChannel!.exitPictureInPicture();
  }

  /// Enters fullscreen mode
  /// Triggers native fullscreen on both Android and iOS
  Future<void> enterFullScreen() async {
    if (_state.isFullScreen) {
      return;
    }

    _updateState(_state.copyWith(isFullScreen: true));

    await _methodChannel?.enterFullScreen();
  }

  /// Exits fullscreen mode
  /// Triggers native fullscreen exit on both Android and iOS
  Future<void> exitFullScreen() async {
    if (!_state.isFullScreen) {
      return;
    }

    _updateState(_state.copyWith(isFullScreen: false));

    await _methodChannel?.exitFullScreen();
  }

  /// Toggles fullscreen mode
  Future<void> toggleFullScreen() async {
    if (_state.isFullScreen) {
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
    if (_state.isFullScreen) {
      await exitFullScreen();
    }

    // Cancel all event channel subscriptions
    for (final StreamSubscription<dynamic> subscription in _eventSubscriptions.values) {
      await subscription.cancel();
    }
    _eventSubscriptions.clear();

    _methodChannel = null;
    _updateState(const NativeVideoPlayerState());
    _url = null;
    _platformViewIds.clear();
    _primaryPlatformViewId = null;
    _initializeCompleter = null;
    _activityEventHandlers.clear();
    _controlEventHandlers.clear();
  }
}
