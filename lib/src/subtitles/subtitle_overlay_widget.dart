import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/native_video_player_controller.dart';
import '../models/native_video_player_subtitle_style.dart';
import 'vtt_parser.dart';

/// A Flutter overlay widget that renders VTT subtitle cues on top of the video
///
/// This widget listens to the controller's position stream and displays
/// the active subtitle cue at the current playback position. Used on iOS
/// for sidecar VTT files where native subtitle rendering is not available.
///
/// On Android, sidecar VTT subtitles are handled natively by ExoPlayer,
/// so this widget is only active on iOS (or when explicitly enabled).
class SubtitleOverlayWidget extends StatefulWidget {
  const SubtitleOverlayWidget({
    required this.controller,
    required this.cues,
    this.style = const NativeVideoPlayerSubtitleStyle(),
    this.visible = true,
    super.key,
  });

  /// The video player controller to listen for position updates
  final NativeVideoPlayerController controller;

  /// The parsed VTT cues to display
  final List<VttCue> cues;

  /// Styling for the subtitle text
  final NativeVideoPlayerSubtitleStyle style;

  /// Whether the subtitle overlay is visible
  final bool visible;

  @override
  State<SubtitleOverlayWidget> createState() => _SubtitleOverlayWidgetState();
}

class _SubtitleOverlayWidgetState extends State<SubtitleOverlayWidget> {
  StreamSubscription<Duration>? _positionSubscription;
  String? _currentText;

  @override
  void initState() {
    super.initState();
    _positionSubscription = widget.controller.positionStream.listen(
      _onPositionChanged,
    );
  }

  @override
  void didUpdateWidget(SubtitleOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _positionSubscription?.cancel();
      _positionSubscription = widget.controller.positionStream.listen(
        _onPositionChanged,
      );
    }
    if (oldWidget.cues != widget.cues) {
      // Re-evaluate current cue with new cues
      _onPositionChanged(widget.controller.currentPosition);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _onPositionChanged(Duration position) {
    if (!mounted) return;

    String? newText;
    for (final cue in widget.cues) {
      if (cue.isActiveAt(position)) {
        newText = cue.text;
        break;
      }
    }

    if (newText != _currentText) {
      setState(() {
        _currentText = newText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || _currentText == null) {
      return const SizedBox.shrink();
    }

    final style = widget.style;
    final textColor = style.fontColor ?? Colors.white;
    final bgColor = style.backgroundColor ?? Colors.black54;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 40,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _currentText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: style.fontSize,
              color: textColor,
              decoration: TextDecoration.none,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
