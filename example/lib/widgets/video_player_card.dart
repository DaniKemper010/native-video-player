import 'dart:async';

import 'package:better_native_video_player/better_native_video_player.dart';
import 'package:flutter/material.dart';

import '../models/video_item.dart';
import 'custom_video_overlay.dart';

class VideoPlayerCard extends StatefulWidget {
  final VideoItem video;
  final Function(NativeVideoPlayerController) onTap;
  final bool useCustomOverlay;

  const VideoPlayerCard({
    super.key,
    required this.video,
    required this.onTap,
    this.useCustomOverlay = false,
  });

  @override
  State<VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<VideoPlayerCard>
    with AutomaticKeepAliveClientMixin {
  NativeVideoPlayerController? _controller;
  String _status = 'Ready';
  PlayerActivityState state = PlayerActivityState.idle;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  bool _shouldCreatePlayer = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _ensureControllerCreated() async {
    if (_controller == null) {
      _controller = NativeVideoPlayerController(
        id: widget.video.id,
        autoPlay: false,
        lockToLandscape: false,
        mediaInfo: NativeVideoPlayerMediaInfo(
          title: widget.video.title,
          subtitle: widget.video.description,
        ),
      );

      _controller!.addActivityListener(_handleActivityEvent);
      _controller!.addControlListener(_handleControlEvent);

      // Set initial status
      setState(() {
        if (_controller == null) return;
        _currentPosition = _controller!.currentPosition;
        _duration = _controller!.duration;
        _status = _getStatusFromActivityState(_controller!.activityState);
        state = _controller!.activityState;
      });

      await _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    if (_controller == null) return;

    try {
      await _controller!.initialize();
      await _controller!.load(url: widget.video.url);

      debugPrint('VideoPlayerCard ${widget.video.id}: Video loaded!');
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          state = PlayerActivityState.error;
        });
      }
      debugPrint('VideoPlayerCard ${widget.video.id} init error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    setState(() {
      _shouldCreatePlayer = true;
      _status = 'Loading...';
      state = PlayerActivityState.loading;
    });
    unawaited(_ensureControllerCreated());
  }

  void _handleActivityEvent(PlayerActivityEvent event) {
    if (!mounted) return;

    setState(() {
      _status = _getStatusFromActivityState(event.state);
      state = event.state;

      // Handle loaded event
      if (event.state == PlayerActivityState.loaded) {
        if (event.data != null) {
          final duration = event.data!['duration'] as int?;
          if (duration != null) {
            _duration = Duration(milliseconds: duration);
            debugPrint(
              'VideoPlayerCard ${widget.video.id}: Duration loaded: ${_duration.inSeconds}s',
            );
          }
        }
      }

      // Handle error
      if (event.state == PlayerActivityState.error) {
        _status = 'Error: ${event.data?['message'] ?? 'Unknown error'}';
        debugPrint('VideoPlayerCard event error: ${event.data}');
      }
    });
  }

  void _handleControlEvent(PlayerControlEvent event) {
    if (!mounted) return;

    setState(() {
      // Handle time update events
      if (event.state == PlayerControlState.timeUpdated) {
        if (event.data != null) {
          final position = event.data!['position'] as int?;
          final duration = event.data!['duration'] as int?;

          if (position != null) {
            _currentPosition = Duration(milliseconds: position);
          }
          if (duration != null) {
            _duration = Duration(milliseconds: duration);
          }
        }
      }
    });
  }

  String _getStatusFromActivityState(PlayerActivityState state) {
    switch (state) {
      case PlayerActivityState.playing:
        return 'Playing';
      case PlayerActivityState.paused:
        return 'Paused';
      case PlayerActivityState.buffering:
        return 'Buffering...';
      case PlayerActivityState.completed:
        return 'Completed';
      case PlayerActivityState.loading:
        return 'Loading...';
      case PlayerActivityState.error:
        return 'Error';
      default:
        return 'Ready';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.removeActivityListener(_handleActivityEvent);
      _controller!.removeControlListener(_handleControlEvent);
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (_controller != null) {
            widget.onTap(_controller!);
          } else {
            _init();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      // Keep the video player in the widget tree but hide it when not current route
                      // This prevents disposing the platform view which would affect playback
                      child: (_shouldCreatePlayer && _controller != null)
                          ? NativeVideoPlayer(
                              controller: _controller!,
                              overlayBuilder: widget.useCustomOverlay
                                  ? (context, controller) => CustomVideoOverlay(
                                      controller: controller,
                                    )
                                  : null,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: state.isPlaying
                                ? Colors.red
                                : _status == 'Buffering...'
                                ? Colors.orange
                                : Colors.grey,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      Text(
                        widget.video.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_currentPosition),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 8),
                      Text('/', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                      IconButton(
                        onPressed: () {
                          _controller?.dispose();
                          _controller = null;
                          setState(() {
                            _shouldCreatePlayer = false;
                            _status = 'Disposed';
                            state = PlayerActivityState.idle;
                          });
                        },
                        icon: Icon(Icons.cancel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
