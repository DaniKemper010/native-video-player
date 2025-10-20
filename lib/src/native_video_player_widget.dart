import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/native_video_player_controller.dart';
import 'enums/native_video_player_event.dart';

/// A native video player widget that wraps platform-specific video players
/// (AVPlayerViewController on iOS, ExoPlayer on Android).
///
/// Android handles fullscreen natively using a Dialog, so only ONE platform view is used.
/// iOS uses native AVPlayerViewController presentation for fullscreen.
class NativeVideoPlayer extends StatefulWidget {
  const NativeVideoPlayer({required this.controller, super.key});

  final NativeVideoPlayerController controller;

  @override
  State<NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends State<NativeVideoPlayer> {
  int? _platformViewId;

  @override
  void dispose() {
    // Notify the controller that this platform view is being disposed
    if (_platformViewId != null) {
      widget.controller.onPlatformViewDisposed(_platformViewId!);
    }

    super.dispose();
  }

  /// Called when the platform view is created
  Future<void> _onPlatformViewCreated(int id) async {
    _platformViewId = id;
    await widget.controller.onPlatformViewCreated(id, context);
  }

  Widget _buildPlatformView() {
    const String viewType = 'native_video_player';

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: widget.controller.creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: widget.controller.creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      );
    }

    return const Text('Only iOS and Android are supported', textAlign: TextAlign.center);
  }

  @override
  Widget build(BuildContext context) => _buildPlatformView();
}
