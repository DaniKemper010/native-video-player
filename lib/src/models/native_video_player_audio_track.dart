/// Represents an audio track in the video player (e.g., from an HLS stream)
///
/// Audio tracks are typically used for:
/// - Multiple language audio tracks (e.g., original audio, dubbed versions)
/// - Audio descriptions for visually impaired users (accessibility)
/// - Commentary tracks (e.g., director's commentary)
/// - Stereo vs. surround sound options
class NativeVideoPlayerAudioTrack {
  const NativeVideoPlayerAudioTrack({
    required this.index,
    required this.language,
    required this.displayName,
    this.isSelected = false,
    this.label,
    this.channels,
    this.bitrate,
  });

  factory NativeVideoPlayerAudioTrack.fromMap(Map<dynamic, dynamic> map) {
    return NativeVideoPlayerAudioTrack(
      index: map['index'] as int,
      language: map['language'] as String,
      displayName: map['displayName'] as String,
      isSelected: map['isSelected'] as bool? ?? false,
      label: map['label'] as String?,
      channels: map['channels'] as int?,
      bitrate: map['bitrate'] as int?,
    );
  }

  /// Returns a default track placeholder
  factory NativeVideoPlayerAudioTrack.defaultTrack() =>
      const NativeVideoPlayerAudioTrack(
        index: 0,
        language: 'und',
        displayName: 'Default',
        isSelected: true,
      );

  /// The index of the audio track (platform-specific identifier)
  final int index;

  /// The language code (e.g., "en", "sl", "de", "en-US")
  final String language;

  /// The display name for the audio track (e.g., "English", "Audio Description")
  final String displayName;

  /// Whether this audio track is currently selected
  final bool isSelected;

  /// Optional label from the HLS manifest (e.g., "Audio Description", "Commentary")
  final String? label;

  /// Optional number of audio channels (e.g., 2 for stereo, 6 for 5.1 surround)
  final int? channels;

  /// Optional audio bitrate in bits per second
  final int? bitrate;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'index': index,
    'language': language,
    'displayName': displayName,
    'isSelected': isSelected,
    if (label != null) 'label': label,
    if (channels != null) 'channels': channels,
    if (bitrate != null) 'bitrate': bitrate,
  };

  NativeVideoPlayerAudioTrack copyWith({
    int? index,
    String? language,
    String? displayName,
    bool? isSelected,
    String? label,
    int? channels,
    int? bitrate,
  }) {
    return NativeVideoPlayerAudioTrack(
      index: index ?? this.index,
      language: language ?? this.language,
      displayName: displayName ?? this.displayName,
      isSelected: isSelected ?? this.isSelected,
      label: label ?? this.label,
      channels: channels ?? this.channels,
      bitrate: bitrate ?? this.bitrate,
    );
  }

  @override
  String toString() =>
      'NativeVideoPlayerAudioTrack(index: $index, language: $language, displayName: $displayName, isSelected: $isSelected, label: $label, channels: $channels, bitrate: $bitrate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeVideoPlayerAudioTrack &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          language == other.language &&
          displayName == other.displayName &&
          isSelected == other.isSelected;

  @override
  int get hashCode => Object.hash(index, language, displayName, isSelected);
}
