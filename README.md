# native_video_player

A Flutter plugin for native video playback on iOS and Android with advanced features.

## Features

- ✅ Native video players: **AVPlayerViewController** on iOS and **ExoPlayer (Media3)** on Android
- ✅ **HLS streaming** support with adaptive quality selection
- ✅ **Picture-in-Picture (PiP)** mode on both platforms
- ✅ Native **fullscreen** playback
- ✅ **Now Playing** integration (Control Center on iOS, lock screen notifications on Android)
- ✅ Background playback with media notifications
- ✅ Playback controls: play, pause, seek, volume, speed
- ✅ Quality selection for HLS streams
- ✅ Event streaming for player state changes

## Platform Support

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 12.0+          |
| Android  | API 24+ (Android 7.0) |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  native_video_player: ^0.0.1
```

Then run:

```bash
flutter pub get
```

### iOS Setup

Add the following to your `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

For Picture-in-Picture support, enable Background Modes in Xcode:
- Target → Signing & Capabilities → Background Modes
- Check "Audio, AirPlay, and Picture in Picture"

### Android Setup

The plugin automatically configures the required permissions and services in its manifest.

## Usage

### Basic Example

```dart
import 'package:flutter/material.dart';
import 'package:native_video_player/native_video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late NativeVideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // Create controller
    _controller = NativeVideoPlayerController(
      id: 1,
      autoPlay: true,
      showNativeControls: true,
    );

    // Listen to events
    _controller.addListener(_handlePlayerEvent);

    // Initialize
    await _controller.initialize();

    // Load video
    await _controller.load(
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    );
  }

  void _handlePlayerEvent(NativeVideoPlayerEvent event) {
    print('Player event: ${event.type}');
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
      body: NativeVideoPlayer(controller: _controller),
    );
  }
}
```

### Advanced Usage

#### Custom Media Info (Now Playing)

```dart
_controller = NativeVideoPlayerController(
  id: 1,
  mediaInfo: const NativeVideoPlayerMediaInfo(
    title: 'My Video Title',
    subtitle: 'Artist or Channel Name',
    album: 'Album Name',
    artworkUrl: 'https://example.com/artwork.jpg',
  ),
);
```

#### Picture-in-Picture Configuration

```dart
_controller = NativeVideoPlayerController(
  id: 1,
  allowsPictureInPicture: true,
  canStartPictureInPictureAutomatically: true, // iOS 14.2+
);
```

#### Playback Controls

```dart
// Play/Pause
await _controller.play();
await _controller.pause();

// Seek
await _controller.seekTo(const Duration(seconds: 30));

// Volume (0.0 to 1.0)
await _controller.setVolume(0.8);

// Speed
await _controller.setSpeed(1.5); // 0.5x, 1.0x, 1.5x, 2.0x, etc.

// Fullscreen
await _controller.enterFullScreen();
await _controller.exitFullScreen();
await _controller.toggleFullScreen();
```

#### Quality Selection (HLS)

```dart
// Get available qualities
final qualities = _controller.qualities;

// Set quality
if (qualities.isNotEmpty) {
  await _controller.setQuality(qualities.first);
}
```

#### Event Handling

```dart
void _handlePlayerEvent(NativeVideoPlayerEvent event) {
  switch (event.type) {
    case NativeVideoPlayerEventType.play:
      print('Playing');
      break;
    case NativeVideoPlayerEventType.pause:
      print('Paused');
      break;
    case NativeVideoPlayerEventType.buffering:
      print('Buffering');
      break;
    case NativeVideoPlayerEventType.completed:
      print('Playback completed');
      break;
    case NativeVideoPlayerEventType.error:
      print('Error: ${event.data?['message']}');
      break;
    case NativeVideoPlayerEventType.fullscreenChange:
      final isFullscreen = event.data?['isFullscreen'] as bool;
      print('Fullscreen: $isFullscreen');
      break;
    default:
      break;
  }
}
```

## API Reference

### NativeVideoPlayerController

#### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `id` | `int` | required | Unique identifier for the player instance |
| `autoPlay` | `bool` | `false` | Start playing automatically after loading |
| `mediaInfo` | `NativeVideoPlayerMediaInfo?` | `null` | Media metadata for Now Playing |
| `allowsPictureInPicture` | `bool` | `true` | Enable Picture-in-Picture |
| `canStartPictureInPictureAutomatically` | `bool` | `true` | Auto-start PiP on app background (iOS 14.2+) |
| `showNativeControls` | `bool` | `true` | Show native player controls |

#### Methods

- `Future<void> initialize()` - Initialize the controller
- `Future<void> load({required String url, Map<String, String>? headers})` - Load video URL
- `Future<void> play()` - Start playback
- `Future<void> pause()` - Pause playback
- `Future<void> seekTo(Duration position)` - Seek to position
- `Future<void> setVolume(double volume)` - Set volume (0.0-1.0)
- `Future<void> setSpeed(double speed)` - Set playback speed
- `Future<void> setQuality(NativeVideoPlayerQuality quality)` - Set video quality
- `Future<void> enterFullScreen()` - Enter fullscreen
- `Future<void> exitFullScreen()` - Exit fullscreen
- `Future<void> toggleFullScreen()` - Toggle fullscreen
- `Future<void> dispose()` - Clean up resources

#### Properties

- `List<NativeVideoPlayerQuality> qualities` - Available HLS quality variants
- `bool isFullScreen` - Current fullscreen state
- `bool isLoaded` - Whether video is loaded
- `String? url` - Current video URL

### Event Types

- `isInitialized` - Controller initialized
- `videoLoaded` - Video loaded successfully
- `play` - Playback started
- `pause` - Playback paused
- `buffering` - Buffering in progress
- `loading` - Loading content
- `completed` - Playback completed
- `error` - Error occurred
- `qualityChange` - Quality changed
- `speedChange` - Speed changed
- `seek` - Seek completed
- `pipStart` - PiP started
- `pipStop` - PiP stopped
- `fullscreenChange` - Fullscreen state changed

## Architecture

### iOS
- Uses `AVPlayerViewController` for video playback
- Implements `FlutterPlatformView` for embedding native views
- Supports HLS streaming with native `AVPlayer`
- Picture-in-Picture via `AVPictureInPictureController`
- Now Playing info via `MPNowPlayingInfoCenter`

### Android
- Uses ExoPlayer (Media3) for video playback
- Implements `PlatformView` with `AndroidView`
- HLS support via Media3 HLS extension
- Picture-in-Picture via native Android PiP APIs
- Media notifications via `MediaSessionService`

## Troubleshooting

### iOS

**Video doesn't play:**
- Check `Info.plist` has `NSAppTransportSecurity` configured
- For local files, ensure proper file access permissions

**PiP not working:**
- Enable Background Modes in Xcode capabilities
- Ensure iOS version is 14.0+

### Android

**Video doesn't play:**
- Check internet permissions in your app's `AndroidManifest.xml`
- Ensure minimum SDK version is 24+

**Fullscreen issues:**
- The plugin handles fullscreen natively with a Dialog
- Ensure proper activity lifecycle management

## Example App

See the `example` folder for a complete working example with:
- Basic playback
- Playback controls
- Speed adjustment
- Fullscreen toggle
- Event handling

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

Developed for the Flutter community. Based on native video player implementations using industry-standard libraries:
- iOS: AVFoundation
- Android: ExoPlayer (Media3)
