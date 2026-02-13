import 'package:flutter/material.dart';

/// Styling options for subtitle/closed caption text
///
/// Controls the visual appearance of subtitle text rendered by the player.
/// On Android, this is applied natively to ExoPlayer's SubtitleView.
/// On iOS with sidecar VTT subtitles, this is applied to the Flutter overlay.
class NativeVideoPlayerSubtitleStyle {
  const NativeVideoPlayerSubtitleStyle({
    this.fontSize = 16.0,
    this.fontColor,
    this.backgroundColor,
  });

  /// The font size for subtitle text in logical pixels (dp/pt)
  ///
  /// Defaults to 16.0. Typical values range from 12.0 (small) to 28.0 (large).
  final double fontSize;

  /// The color of the subtitle text
  ///
  /// Defaults to white if not specified.
  final Color? fontColor;

  /// The background color behind the subtitle text
  ///
  /// Defaults to semi-transparent black if not specified.
  final Color? backgroundColor;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'fontSize': fontSize,
    if (fontColor != null) 'fontColor': fontColor!.toARGB32(),
    if (backgroundColor != null)
      'backgroundColor': backgroundColor!.toARGB32(),
  };

  NativeVideoPlayerSubtitleStyle copyWith({
    double? fontSize,
    Color? fontColor,
    Color? backgroundColor,
  }) {
    return NativeVideoPlayerSubtitleStyle(
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  @override
  String toString() =>
      'NativeVideoPlayerSubtitleStyle(fontSize: $fontSize, fontColor: $fontColor, backgroundColor: $backgroundColor)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeVideoPlayerSubtitleStyle &&
          runtimeType == other.runtimeType &&
          fontSize == other.fontSize &&
          fontColor == other.fontColor &&
          backgroundColor == other.backgroundColor;

  @override
  int get hashCode => Object.hash(fontSize, fontColor, backgroundColor);
}
