import 'package:better_native_video_player/better_native_video_player.dart';
import 'package:flutter/material.dart';

import '../models/video_item.dart';
import '../widgets/audio_picker_modal.dart';
import '../widgets/custom_video_overlay.dart';

/// Example screen demonstrating multi-audio track support
/// Shows how to list and switch between audio tracks in different languages
class AudioExampleScreen extends StatefulWidget {
  const AudioExampleScreen({super.key});

  @override
  State<AudioExampleScreen> createState() => _AudioExampleScreenState();
}

class _AudioExampleScreenState extends State<AudioExampleScreen> {
  late NativeVideoPlayerController _controller;
  bool _isLoadingAudioTracks = false;

  // Using Apple's example HLS stream which has multiple audio tracks
  final video = VideoItem(
    title: 'HLS Stream with Multiple Audio Tracks',
    description: 'Example video with audio in multiple languages',
    url:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
    id: 2,
    artworkUrl: '',
  );

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _controller = NativeVideoPlayerController(
      id: 998,
      autoPlay: true,
      mediaInfo: NativeVideoPlayerMediaInfo(
        title: video.title,
        subtitle: video.description,
      ),
    );

    _loadVideo(video.url);

    // Listen for video loaded event to fetch audio tracks
    _controller.addActivityListener((event) {
      if (event.state == PlayerActivityState.playing) {
        _loadAudioTracks();
      }
    });

    // Listen for audio track changes
    _controller.addControlListener((event) {
      if (event.state == PlayerControlState.audioTrackChanged) {
        _loadAudioTracks(); // Refresh the list to show the new selection
      }
    });
  }

  Future<void> _loadVideo(String url) async {
    try {
      await _controller.initialize();
      await _controller.load(url: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading video: $e')));
      }
    }
  }

  Future<void> _loadAudioTracks() async {
    if (_isLoadingAudioTracks) return;

    setState(() {
      _isLoadingAudioTracks = true;
    });

    try {
      // Wait a bit for the video to fully load
      await Future.delayed(const Duration(seconds: 1));

      await _controller.getAvailableAudioTracks();

      if (mounted) {
        setState(() {
          _isLoadingAudioTracks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAudioTracks = false;
        });
      }
    }
  }

  void _showAudioPicker() {
    showAudioPicker(context, _controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Audio Track Examples',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Video Player
            Expanded(
              flex: 2,
              child: NativeVideoPlayer(
                controller: _controller,
                overlayBuilder: (context, controller) =>
                    CustomVideoOverlay(controller: controller),
              ),
            ),

            // Audio Track Info Section
            Expanded(
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.audiotrack,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Available Audio Tracks',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingAudioTracks)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAudioPicker,
                        icon: const Icon(Icons.settings_voice),
                        label: const Text('Change Audio Track'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[300],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tap "Change Audio Track" to switch between available audio languages',
                              style: TextStyle(
                                color: Colors.blue[100],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
