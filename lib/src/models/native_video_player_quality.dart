class NativeVideoPlayerQuality {
  const NativeVideoPlayerQuality({required this.label, required this.url});

  factory NativeVideoPlayerQuality.fromMap(Map<dynamic, dynamic> map) =>
      NativeVideoPlayerQuality(label: map['label'] as String, url: map['url'] as String);

  final String label;
  final String url;

  Map<String, String> toMap() => <String, String>{'label': label, 'url': url};

  @override
  String toString() => 'NativeVideoPlayerQuality(label: $label, url: $url)';
}
