enum NativeVideoPlayerEventType {
  isInitialized,
  videoLoaded,
  play,
  pause,
  buffering,
  loading,
  completed,
  error,
  qualityChange,
  speedChange,
  seek,
  pipStart,
  pipStop,
  stopped,
  fullscreenChange,
}

extension NativeVideoPlayerEventTypeExtension on NativeVideoPlayerEventType {
  bool get isInitialized =>
      this == NativeVideoPlayerEventType.isInitialized && this != NativeVideoPlayerEventType.error;

  bool get isLoading => this == NativeVideoPlayerEventType.loading;

  bool get isVideoLoaded => this == NativeVideoPlayerEventType.videoLoaded;

  bool get isPlaying => this == NativeVideoPlayerEventType.play;

  bool get isBuffering => this == NativeVideoPlayerEventType.buffering;

  bool get isPaused => this == NativeVideoPlayerEventType.pause;

  bool get hasError => this == NativeVideoPlayerEventType.error;

  bool get isCompleted => this == NativeVideoPlayerEventType.completed;

  bool get isFullscreenChange => this == NativeVideoPlayerEventType.fullscreenChange;
}

class NativeVideoPlayerEvent {
  const NativeVideoPlayerEvent({required this.type, this.data});

  factory NativeVideoPlayerEvent.fromMap(Map<dynamic, dynamic> map) {
    final String eventName = map['event'] as String;
    final NativeVideoPlayerEventType type = _eventTypeFromString(eventName);

    final Map<String, dynamic> data = Map<String, dynamic>.from(map)..remove('event');

    return NativeVideoPlayerEvent(type: type, data: data.isEmpty ? null : data);
  }

  final NativeVideoPlayerEventType type;
  final Map<String, dynamic>? data;

  static NativeVideoPlayerEventType _eventTypeFromString(String event) {
    switch (event) {
      case 'isInitialized':
        return NativeVideoPlayerEventType.isInitialized;
      case 'videoLoaded':
        return NativeVideoPlayerEventType.videoLoaded;
      case 'play':
        return NativeVideoPlayerEventType.play;
      case 'pause':
        return NativeVideoPlayerEventType.pause;
      case 'buffering':
        return NativeVideoPlayerEventType.buffering;
      case 'loading':
        return NativeVideoPlayerEventType.loading;
      case 'completed':
        return NativeVideoPlayerEventType.completed;
      case 'error':
        return NativeVideoPlayerEventType.error;
      case 'qualityChange':
        return NativeVideoPlayerEventType.qualityChange;
      case 'speedChange':
        return NativeVideoPlayerEventType.speedChange;
      case 'seek':
        return NativeVideoPlayerEventType.seek;
      case 'pipStart':
        return NativeVideoPlayerEventType.pipStart;
      case 'pipStop':
        return NativeVideoPlayerEventType.pipStop;
      case 'stopped':
        return NativeVideoPlayerEventType.stopped;
      case 'fullscreenChange':
        return NativeVideoPlayerEventType.fullscreenChange;
      default:
        return NativeVideoPlayerEventType.error;
    }
  }
}
