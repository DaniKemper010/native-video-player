class NativeVideoPlayerQuality {
  const NativeVideoPlayerQuality({
    required this.label,
    required this.url,
    this.bitrate,
    this.width,
    this.height,
    this.isAuto = false,
  });

  factory NativeVideoPlayerQuality.fromMap(Map<dynamic, dynamic> map) {
    // Parse resolution from label if available (e.g., "1280x720")
    int? width, height;
    final label = map['label'] as String;
    final resolutionMatch = RegExp(r'(\d+)x(\d+)').firstMatch(label);
    if (resolutionMatch != null) {
      width = int.tryParse(resolutionMatch.group(1)!);
      height = int.tryParse(resolutionMatch.group(2)!);
    }

    return NativeVideoPlayerQuality(
      label: label,
      url: map['url'] as String,
      bitrate: map['bitrate'] as int?,
      width: width,
      height: height,
      isAuto: map['isAuto'] as bool? ?? false,
    );
  }

  factory NativeVideoPlayerQuality.auto() =>
      const NativeVideoPlayerQuality(label: 'Auto', url: '', isAuto: true);

  final String label;
  final String url;
  final int? bitrate;
  final int? width;
  final int? height;
  final bool isAuto;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'label': label,
    'url': url,
    if (bitrate != null) 'bitrate': bitrate,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    'isAuto': isAuto,
  };

  @override
  String toString() =>
      'NativeVideoPlayerQuality(label: $label, url: $url, bitrate: $bitrate, resolution: ${width}x$height, isAuto: $isAuto)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeVideoPlayerQuality &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          url == other.url &&
          bitrate == other.bitrate &&
          width == other.width &&
          height == other.height &&
          isAuto == other.isAuto;

  @override
  int get hashCode => Object.hash(label, url, bitrate, width, height, isAuto);
}
