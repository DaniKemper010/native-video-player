import 'package:flutter/material.dart';
import 'package:native_video_player/native_video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Video Player Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const VideoPlayerPage(),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late NativeVideoPlayerController _controller;
  String _status = 'Initializing...';

  // Sample HLS video URL
  static const String videoUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = NativeVideoPlayerController(
      id: 1,
      autoPlay: false,
      showNativeControls: true,
      mediaInfo: const NativeVideoPlayerMediaInfo(title: 'Sample Video', subtitle: 'Native Video Player Demo'),
    );

    // Listen to player events
    _controller.addListener(_handlePlayerEvent);

    // Initialize the controller
    await _controller.initialize();

    // Load the video
    await _controller.load(url: videoUrl);

    setState(() {
      _status = 'Ready to play';
    });
  }

  void _handlePlayerEvent(NativeVideoPlayerEvent event) {
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
        case NativeVideoPlayerEventType.error:
          _status = 'Error: ${event.data?['message'] ?? 'Unknown error'}';
          break;
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePlayerEvent);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Video Player'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Video Player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: NativeVideoPlayer(controller: _controller),
            ),
          ),

          // Status
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_status, style: Theme.of(context).textTheme.titleMedium),
          ),

          // Controls
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _controller.play(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
              ElevatedButton.icon(
                onPressed: () => _controller.pause(),
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
              ElevatedButton.icon(
                onPressed: () => _controller.toggleFullScreen(),
                icon: const Icon(Icons.fullscreen),
                label: const Text('Fullscreen'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Speed Controls
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('Playback Speed:')),
          Wrap(
            spacing: 8,
            children: [
              for (final speed in [0.5, 1.0, 1.5, 2.0])
                OutlinedButton(onPressed: () => _controller.setSpeed(speed), child: Text('${speed}x')),
            ],
          ),
        ],
      ),
    );
  }
}
