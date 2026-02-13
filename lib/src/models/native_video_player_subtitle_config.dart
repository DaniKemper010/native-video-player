/// Configuration for a sidecar (external) subtitle file
///
/// Used when loading external VTT subtitle files alongside a video.
/// This is different from HLS-embedded subtitles which are discovered
/// automatically by the native player.
class NativeVideoPlayerSubtitleConfig {
  const NativeVideoPlayerSubtitleConfig({
    this.language = 'en',
    this.label = 'English',
    this.selected = true,
  });

  /// The language code for the subtitle track (e.g., "en", "es", "fr")
  final String language;

  /// The display label for the subtitle track (e.g., "English", "Spanish")
  final String label;

  /// Whether this subtitle track should be selected by default
  final bool selected;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'language': language,
    'label': label,
    'selected': selected,
  };

  @override
  String toString() =>
      'NativeVideoPlayerSubtitleConfig(language: $language, label: $label, selected: $selected)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeVideoPlayerSubtitleConfig &&
          runtimeType == other.runtimeType &&
          language == other.language &&
          label == other.label &&
          selected == other.selected;

  @override
  int get hashCode => Object.hash(language, label, selected);
}
