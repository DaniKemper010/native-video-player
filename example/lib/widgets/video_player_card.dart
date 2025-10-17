import 'package:flutter/material.dart';
import 'package:native_video_player/native_video_player.dart';

import '../models/video_item.dart';

class VideoPlayerCard extends StatefulWidget {
  final VideoItem video;
  final Function(NativeVideoPlayerController) onTap;

  const VideoPlayerCard({super.key, required this.video, required this.onTap});

  @override
  State<VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<VideoPlayerCard> {
  late NativeVideoPlayerController _controller;
  String _status = 'Ready';
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Just create the controller, don't call initialize()
    // The NativeVideoPlayer widget will handle initialization when it builds
    _controller = NativeVideoPlayerController(
      id: widget.video.id,
      autoPlay: false,
      showNativeControls: true,
      mediaInfo: NativeVideoPlayerMediaInfo(title: widget.video.title, subtitle: widget.video.description),
    );

    _controller.addListener(_handlePlayerEvent);

    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      await _controller.initialize();
      await _controller.load(url: widget.video.url);
      debugPrint('VideoPlayerCard ${widget.video.id}: Video loaded!');
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
        });
      }
      debugPrint('VideoPlayerCard ${widget.video.id} init error: $e');
    }
  }

  void _handlePlayerEvent(NativeVideoPlayerEvent event) {
    if (!mounted) return;

    setState(() {
      switch (event.type) {
        case NativeVideoPlayerEventType.play:
          _status = 'Playing';
          break;
        case NativeVideoPlayerEventType.pause:
          _status = 'Paused';
          break;
        case NativeVideoPlayerEventType.buffering:
          _status = 'Buffering...';
          break;
        case NativeVideoPlayerEventType.completed:
          _status = 'Completed';
          break;
        case NativeVideoPlayerEventType.videoLoaded:
          // Video is loaded, get the duration
          if (event.data != null) {
            final duration = event.data!['duration'] as int?;
            if (duration != null) {
              _duration = Duration(milliseconds: duration);
              debugPrint('VideoPlayerCard ${widget.video.id}: Duration loaded: ${_duration.inSeconds}s');
            }
          }
          break;
        case NativeVideoPlayerEventType.timeUpdate:
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
          break;
        case NativeVideoPlayerEventType.error:
          _status = 'Error: ${event.data?['message'] ?? 'Unknown error'}';
          debugPrint('VideoPlayerCard event error: ${event.data}');
          break;
        default:
          break;
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePlayerEvent);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => widget.onTap(_controller),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: NativeVideoPlayer(controller: _controller),
                    ),
                  ),
                  // Play/Pause Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black..withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                          child: IconButton(
                            icon: Icon(
                              _status == 'Playing' ? Icons.pause : Icons.play_arrow,
                              size: 36,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              if (_status == 'Playing') {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Duration Badge
                  if (_duration.inSeconds > 0)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          _formatDuration(_duration),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  // Status Badge
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _status == 'Playing'
                            ? Colors.red
                            : _status == 'Buffering...'
                            ? Colors.orange
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _status,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Bar
            if (_duration.inSeconds > 0)
              LinearProgressIndicator(
                value: _duration.inMilliseconds > 0 ? _currentPosition.inMilliseconds / _duration.inMilliseconds : 0,
                backgroundColor: Colors.grey[300],
                minHeight: 3,
              ),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(_formatDuration(_currentPosition), style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      const SizedBox(width: 8),
                      Text('/', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      Text(_formatDuration(_duration), style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
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
