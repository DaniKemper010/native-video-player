/// Represents an audio track in the video player
class NativeVideoPlayerAudioTrack {
  const NativeVideoPlayerAudioTrack({
    required this.index,
    required this.language,
    required this.displayName,
    this.codec,
    this.isSelected = false,
  });

  factory NativeVideoPlayerAudioTrack.fromMap(Map<dynamic, dynamic> map) {
    return NativeVideoPlayerAudioTrack(
      index: map['index'] as int,
      language: map['language'] as String,
      displayName: map['displayName'] as String,
      codec: map['codec'] as String?,
      isSelected: map['isSelected'] as bool? ?? false,
    );
  }

  /// Represents an "Auto" or "Default" audio option
  factory NativeVideoPlayerAudioTrack.auto() =>
      const NativeVideoPlayerAudioTrack(
        index: -1,
        language: 'auto',
        displayName: 'Auto',
        isSelected: false,
      );

  /// The index of the audio track (platform-specific identifier)
  final int index;

  /// The language code (e.g., "en", "es", "fr", "en-US")
  final String language;

  /// The display name for the audio track (e.g., "English", "Spanish (Latin America)")
  final String displayName;

  /// The codec of the audio track (e.g., "AAC", "AC3", "MP3"), if available
  final String? codec;

  /// Whether this audio track is currently selected
  final bool isSelected;

  /// Whether this is the "Auto" option
  bool get isAuto => index == -1;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'index': index,
    'language': language,
    'displayName': displayName,
    if (codec != null) 'codec': codec,
    'isSelected': isSelected,
  };

  NativeVideoPlayerAudioTrack copyWith({
    int? index,
    String? language,
    String? displayName,
    String? codec,
    bool? isSelected,
  }) {
    return NativeVideoPlayerAudioTrack(
      index: index ?? this.index,
      language: language ?? this.language,
      displayName: displayName ?? this.displayName,
      codec: codec ?? this.codec,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  String toString() =>
      'NativeVideoPlayerAudioTrack(index: $index, language: $language, displayName: $displayName, codec: $codec, isSelected: $isSelected)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeVideoPlayerAudioTrack &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          language == other.language &&
          displayName == other.displayName &&
          codec == other.codec &&
          isSelected == other.isSelected;

  @override
  int get hashCode =>
      Object.hash(index, language, displayName, codec, isSelected);
}
