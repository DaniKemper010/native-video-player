import 'native_video_player_quality.dart';

/// Represents the state of the native video player
class NativeVideoPlayerState {
  const NativeVideoPlayerState({
    this.isFullScreen = false,
    this.currentPosition = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.volume = 1.0,
    this.qualities = const <NativeVideoPlayerQuality>[],
    this.isInitialized = false,
    this.isLoaded = false,
  });

  /// Whether the video is currently in fullscreen mode
  final bool isFullScreen;

  /// Current playback position
  final Duration currentPosition;

  /// Total video duration
  final Duration duration;

  /// Buffered position (how far the video has been buffered)
  final Duration bufferedPosition;

  /// Current volume (0.0 to 1.0)
  final double volume;

  /// Available video qualities (HLS variants)
  final List<NativeVideoPlayerQuality> qualities;

  /// Whether the controller has been initialized
  final bool isInitialized;

  /// Whether the controller has been loaded and is ready to use
  final bool isLoaded;

  /// Creates a copy of this state with the given fields replaced with new values
  NativeVideoPlayerState copyWith({
    bool? isFullScreen,
    Duration? currentPosition,
    Duration? duration,
    Duration? bufferedPosition,
    double? volume,
    List<NativeVideoPlayerQuality>? qualities,
    bool? isInitialized,
    bool? isLoaded,
  }) {
    return NativeVideoPlayerState(
      isFullScreen: isFullScreen ?? this.isFullScreen,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      volume: volume ?? this.volume,
      qualities: qualities ?? this.qualities,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NativeVideoPlayerState &&
        other.isFullScreen == isFullScreen &&
        other.currentPosition == currentPosition &&
        other.duration == duration &&
        other.bufferedPosition == bufferedPosition &&
        other.volume == volume &&
        other.qualities == qualities &&
        other.isInitialized == isInitialized &&
        other.isLoaded == isLoaded;
  }

  @override
  int get hashCode {
    return Object.hash(
      isFullScreen,
      currentPosition,
      duration,
      bufferedPosition,
      volume,
      qualities,
      isInitialized,
      isLoaded,
    );
  }
}
