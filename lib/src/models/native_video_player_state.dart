import '../enums/native_video_player_event.dart';
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
    this.activityState = PlayerActivityState.idle,
    this.controlState = PlayerControlState.none,
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

  /// Current activity state (playing, paused, buffering, etc.)
  final PlayerActivityState activityState;

  /// Current control state (quality change, speed change, pip, fullscreen, etc.)
  final PlayerControlState controlState;

  /// Creates a copy of this state with the given fields replaced with new values
  NativeVideoPlayerState copyWith({
    bool? isFullScreen,
    Duration? currentPosition,
    Duration? duration,
    Duration? bufferedPosition,
    double? volume,
    List<NativeVideoPlayerQuality>? qualities,
    PlayerActivityState? activityState,
    PlayerControlState? controlState,
  }) {
    return NativeVideoPlayerState(
      isFullScreen: isFullScreen ?? this.isFullScreen,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      volume: volume ?? this.volume,
      qualities: qualities ?? this.qualities,
      activityState: activityState ?? this.activityState,
      controlState: controlState ?? this.controlState,
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
        other.activityState == activityState &&
        other.controlState == controlState;
  }

  @override
  int get hashCode {
    return Object.hash(isFullScreen, currentPosition, duration, bufferedPosition, volume, qualities, activityState, controlState);
  }
}
