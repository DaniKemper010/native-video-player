class NativeVideoPlayerMediaInfo {
  const NativeVideoPlayerMediaInfo({
    this.title,
    this.subtitle,
    this.album,
    this.artworkUrl,
  });

  final String? title;
  final String? subtitle;
  final String? album;
  final String? artworkUrl;

  Map<String, dynamic> toMap() => <String, dynamic>{
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (album != null) 'album': album,
    if (artworkUrl != null) 'artworkUrl': artworkUrl,
  };
}
