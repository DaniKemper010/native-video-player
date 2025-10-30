import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'controllers/native_video_player_controller.dart';
import 'enums/native_video_player_event.dart';

/// A native video player widget that wraps platform-specific video players
/// (AVPlayerViewController on iOS, ExoPlayer on Android).
///
/// Android handles fullscreen natively using a Dialog, so only ONE platform view is used.
/// iOS uses native AVPlayerViewController presentation for fullscreen.
class NativeVideoPlayer extends StatefulWidget {
  const NativeVideoPlayer({
    required this.controller,
    this.overlayBuilder,
    this.overlayFadeDuration = const Duration(milliseconds: 300),
    super.key,
  });

  final NativeVideoPlayerController controller;

  /// Optional overlay widget builder that renders on top of the video player.
  /// The builder receives the BuildContext and controller to build custom controls.
  /// The overlay is displayed in both normal and fullscreen modes with fade animations.
  final Widget Function(
    BuildContext context,
    NativeVideoPlayerController controller,
  )?
  overlayBuilder;

  /// Duration for overlay fade in/out animations.
  /// Defaults to 300ms.
  final Duration overlayFadeDuration;

  @override
  State<NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends State<NativeVideoPlayer>
    with SingleTickerProviderStateMixin {
  int? _platformViewId;
  late AnimationController _overlayAnimationController;
  late Animation<double> _overlayOpacity;
  bool _overlayVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Pass the overlay builder to the controller
    widget.controller.setOverlayBuilder(widget.overlayBuilder);

    // Set up animation controller for overlay fade
    _overlayAnimationController = AnimationController(
      duration: widget.overlayFadeDuration,
      vsync: this,
    );

    _overlayOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _overlayAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start with overlay visible if we have one
    if (widget.overlayBuilder != null) {
      _overlayAnimationController.value = 1.0;
      _startHideTimer();
    }

    // Listen to controller events to restart hide timer on user interaction
    widget.controller.addControlListener(_handleControlEvent);
  }

  void _handleControlEvent(PlayerControlEvent event) {
    // Hide overlay when entering PiP (Android only)
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (event.state == PlayerControlState.pipStarted && _overlayVisible) {
        setState(() {
          _overlayVisible = false;
          _overlayAnimationController.reverse();
          _hideTimer?.cancel();
        });
        return;
      }

      // Show overlay when exiting PiP (Android only)
      if (event.state == PlayerControlState.pipStopped && !_overlayVisible) {
        setState(() {
          _overlayVisible = true;
          _overlayAnimationController.forward();
          _startHideTimer();
        });
        return;
      }
    }

    // Show overlay when exiting fullscreen
    if (event.state == PlayerControlState.fullscreenExited &&
        !_overlayVisible) {
      setState(() {
        _overlayVisible = true;
        _overlayAnimationController.forward();
        _startHideTimer();
      });
    }

    // Restart hide timer on any control interaction (except time updates)
    if (_overlayVisible && event.state != PlayerControlState.timeUpdated) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _overlayVisible) {
        setState(() {
          _overlayVisible = false;
          _overlayAnimationController.reverse();
        });
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _overlayVisible = !_overlayVisible;
      if (_overlayVisible) {
        _overlayAnimationController.forward();
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
        _overlayAnimationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    // Notify the controller that this platform view is being disposed
    if (_platformViewId != null) {
      widget.controller.onPlatformViewDisposed(_platformViewId!);
    }

    widget.controller.removeControlListener(_handleControlEvent);
    _hideTimer?.cancel();
    _overlayAnimationController.dispose();
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
      // Use PlatformViewLink with AndroidViewSurface to enable Hybrid Composition
      // This fixes video scaling/cropping issues that occur with Virtual Display mode
      return PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          final AndroidViewController controller =
              PlatformViewsService.initSurfaceAndroidView(
                id: params.id,
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: widget.controller.creationParams,
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () {
                  params.onFocusChanged(true);
                },
              );
          controller.addOnPlatformViewCreatedListener(
            params.onPlatformViewCreated,
          );
          controller.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
          return controller..create();
        },
      );
    }

    return const Text(
      'Only iOS and Android are supported',
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final platformView = _buildPlatformView();

    // If no overlay builder is provided, return just the platform view
    if (widget.overlayBuilder == null) {
      return platformView;
    }

    // Wrap platform view with animated overlay in a Stack
    return Stack(
      children: [
        // Platform view
        platformView,
        // Transparent tap layer when overlay is hidden
        if (!_overlayVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
        // Animated overlay with tap-to-hide
        FadeTransition(
          opacity: _overlayOpacity,
          child: GestureDetector(
            onTap: _overlayVisible ? _toggleOverlay : null,
            behavior: HitTestBehavior.deferToChild,
            child: IgnorePointer(
              ignoring: !_overlayVisible,
              child: widget.overlayBuilder!(context, widget.controller),
            ),
          ),
        ),
      ],
    );
  }
}
