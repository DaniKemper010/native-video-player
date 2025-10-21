# better_native_video_player

[![pub package](https://img.shields.io/pub/v/better_native_video_player.svg)](https://pub.dev/packages/better_native_video_player)

A Flutter plugin for native video playback on iOS and Android with advanced features.

## Features

- ✅ Native video players: **AVPlayerViewController** on iOS and **ExoPlayer (Media3)** on Android
- ✅ **HLS streaming** support with adaptive quality selection
- ✅ **Picture-in-Picture (PiP)** mode on both platforms with automatic state management
- ✅ **AirPlay** support on iOS with availability detection and connection events
- ✅ Native **fullscreen** playback with Dart-side fullscreen option
- ✅ **Custom overlay controls** - Build your own UI on top of native player
- ✅ **Now Playing** integration (Control Center on iOS, lock screen notifications on Android)
- ✅ Background playback with media notifications
- ✅ Playback controls: play, pause, seek, volume, speed (0.25x - 2.0x)
- ✅ Quality selection for HLS streams with real-time switching
- ✅ **Separated event streams**: Activity events (play/pause/buffering) and Control events (quality/speed/PiP/fullscreen)
- ✅ Real-time playback position tracking with **buffered position indicator**
- ✅ Custom HTTP headers support for video requests
- ✅ Multiple controller instances support with shared player management
- ✅ **WASM compatible** - Package works with Web Assembly runtime

## Platform Support

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 12.0+          |
| Android  | API 24+ (Android 7.0) |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  better_native_video_player: ^0.2.2
```

Then run:

```bash
flutter pub get
```

### iOS Setup

This plugin supports both **CocoaPods** and **Swift Package Manager (SPM)**. Flutter will automatically use the appropriate dependency manager based on your project configuration.

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
import 'package:better_native_video_player/better_native_video_player.dart';

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

#### Separated Event Handling

The plugin separates events into two categories for better control:

**Activity Events** - Playback state changes:
```dart
@override
void initState() {
  super.initState();
  _controller.addActivityListener(_handleActivityEvent);
  _controller.addControlListener(_handleControlEvent);
}

void _handleActivityEvent(PlayerActivityEvent event) {
  switch (event.state) {
    case PlayerActivityState.playing:
      print('Playing');
      break;
    case PlayerActivityState.paused:
      print('Paused');
      break;
    case PlayerActivityState.buffering:
      final buffered = event.data?['buffered'] as int?;
      print('Buffering... buffered position: $buffered ms');
      break;
    case PlayerActivityState.completed:
      print('Playback completed');
      break;
    case PlayerActivityState.error:
      print('Error: ${event.data?['message']}');
      break;
    default:
      break;
  }
}
```

**Control Events** - User interactions and settings:
```dart
void _handleControlEvent(PlayerControlEvent event) {
  switch (event.state) {
    case PlayerControlState.timeUpdated:
      final position = event.data?['position'] as int?;
      final duration = event.data?['duration'] as int?;
      final bufferedPosition = event.data?['bufferedPosition'] as int?;
      print('Position: $position ms / $duration ms (buffered: $bufferedPosition ms)');
      break;
    case PlayerControlState.qualityChanged:
      final quality = event.data?['quality'];
      print('Quality changed: $quality');
      break;
    case PlayerControlState.pipStarted:
      print('PiP mode started');
      break;
    case PlayerControlState.pipStopped:
      print('PiP mode stopped');
      break;
    case PlayerControlState.fullscreenEntered:
      print('Entered fullscreen');
      break;
    case PlayerControlState.fullscreenExited:
      print('Exited fullscreen');
      break;
    default:
      break;
  }
}

@override
void dispose() {
  _controller.removeActivityListener(_handleActivityEvent);
  _controller.removeControlListener(_handleControlEvent);
  _controller.dispose();
  super.dispose();
}
```

#### Custom HTTP Headers

```dart
await _controller.load(
  url: 'https://example.com/video.m3u8',
  headers: {
    'Referer': 'https://example.com',
    'Authorization': 'Bearer token',
  },
);
```

#### Picture-in-Picture Mode

```dart
// Check if PiP is available on the device
final isPipAvailable = await _controller.isPictureInPictureAvailable();

if (isPipAvailable) {
  // Enter PiP mode
  await _controller.enterPictureInPicture();

  // Exit PiP mode
  await _controller.exitPictureInPicture();
}

// Listen for PiP state changes
_controller.addControlListener((event) {
  if (event.state == PlayerControlState.pipStarted) {
    print('Entered PiP mode');
  } else if (event.state == PlayerControlState.pipStopped) {
    print('Exited PiP mode');
  }
});
```

#### AirPlay (iOS Only)

AirPlay allows streaming video to Apple TV, HomePod, and other AirPlay-enabled devices.

```dart
@override
void initState() {
  super.initState();

  // Listen for AirPlay availability changes
  _controller.addAirPlayAvailabilityListener(_handleAirPlayAvailability);

  // Listen for AirPlay connection state
  _controller.addAirPlayConnectionListener(_handleAirPlayConnection);
}

void _handleAirPlayAvailability(bool isAvailable) {
  print('AirPlay devices available: $isAvailable');
  // Show/hide AirPlay button in your UI
}

void _handleAirPlayConnection(bool isConnected) {
  print('Connected to AirPlay: $isConnected');
  // Update UI to show AirPlay is active
}

// Check if AirPlay is available
final isAvailable = await _controller.isAirPlayAvailable();

// Show AirPlay device picker
if (isAvailable) {
  await _controller.showAirPlayPicker();
}

@override
void dispose() {
  _controller.removeAirPlayAvailabilityListener(_handleAirPlayAvailability);
  _controller.removeAirPlayConnectionListener(_handleAirPlayConnection);
  _controller.dispose();
  super.dispose();
}
```

#### Custom Overlay Controls

Build your own video controls UI on top of the native player:

```dart
NativeVideoPlayer(
  controller: _controller,
  overlayBuilder: (context, controller) {
    return CustomVideoOverlay(controller: controller);
  },
)
```

Create a custom overlay widget:

```dart
class CustomVideoOverlay extends StatefulWidget {
  final NativeVideoPlayerController controller;

  const CustomVideoOverlay({required this.controller, super.key});

  @override
  State<CustomVideoOverlay> createState() => _CustomVideoOverlayState();
}

class _CustomVideoOverlayState extends State<CustomVideoOverlay> {
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  PlayerActivityState _activityState = PlayerActivityState.idle;

  @override
  void initState() {
    super.initState();
    widget.controller.addActivityListener(_handleActivityEvent);
    widget.controller.addControlListener(_handleControlEvent);

    // Get initial state
    _currentPosition = widget.controller.currentPosition;
    _duration = widget.controller.duration;
    _bufferedPosition = widget.controller.bufferedPosition;
    _activityState = widget.controller.activityState;
  }

  void _handleActivityEvent(PlayerActivityEvent event) {
    if (!mounted) return;
    setState(() {
      _activityState = event.state;
    });
  }

  void _handleControlEvent(PlayerControlEvent event) {
    if (!mounted) return;

    if (event.state == PlayerControlState.timeUpdated) {
      setState(() {
        _currentPosition = widget.controller.currentPosition;
        _duration = widget.controller.duration;
        _bufferedPosition = widget.controller.bufferedPosition;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Center play/pause button
        Center(
          child: IconButton(
            icon: Icon(
              _activityState.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
            onPressed: () {
              if (_activityState.isPlaying) {
                widget.controller.pause();
              } else {
                widget.controller.play();
              }
            },
          ),
        ),

        // Progress bar with buffered indicator
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Slider(
            value: _currentPosition.inMilliseconds.toDouble(),
            min: 0,
            max: _duration.inMilliseconds.toDouble(),
            // Shows buffered position
            secondaryTrackValue: _bufferedPosition.inMilliseconds.toDouble(),
            onChanged: (value) {
              widget.controller.seekTo(Duration(milliseconds: value.toInt()));
            },
          ),
        ),

        // Fullscreen button
        Positioned(
          top: 20,
          right: 20,
          child: IconButton(
            icon: Icon(
              widget.controller.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: () {
              widget.controller.toggleFullScreen();
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.controller.removeActivityListener(_handleActivityEvent);
    widget.controller.removeControlListener(_handleControlEvent);
    super.dispose();
  }
}
```

Features you can add to custom overlays:
- **Playback controls**: Play, pause, skip forward/backward
- **Progress bar**: Current position with buffered position indicator
- **Speed controls**: 0.25x, 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x
- **Quality selector**: Switch between HLS quality variants
- **Fullscreen toggle**: Enter/exit fullscreen
- **Volume control**: Adjust playback volume
- **AirPlay button**: Show AirPlay picker (iOS only)
- **Auto-hide**: Fade out controls after inactivity
- **Loading indicators**: Show when buffering

See `example/lib/widgets/custom_video_overlay.dart` for a complete implementation.

#### Multiple Video Players

```dart
class MultiPlayerScreen extends StatefulWidget {
  @override
  State<MultiPlayerScreen> createState() => _MultiPlayerScreenState();
}

class _MultiPlayerScreenState extends State<MultiPlayerScreen> {
  late NativeVideoPlayerController _controller1;
  late NativeVideoPlayerController _controller2;

  @override
  void initState() {
    super.initState();

    // Create multiple controllers with unique IDs
    _controller1 = NativeVideoPlayerController(id: 1, autoPlay: false);
    _controller2 = NativeVideoPlayerController(id: 2, autoPlay: false);

    _initializePlayers();
  }

  Future<void> _initializePlayers() async {
    await _controller1.initialize();
    await _controller2.initialize();

    await _controller1.load(url: 'https://example.com/video1.m3u8');
    await _controller2.load(url: 'https://example.com/video2.m3u8');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: NativeVideoPlayer(controller: _controller1)),
        Expanded(child: NativeVideoPlayer(controller: _controller2)),
      ],
    );
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
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

### NativeVideoPlayer Widget

#### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `controller` | `NativeVideoPlayerController` | required | The controller for the video player |
| `overlayBuilder` | `Widget Function(BuildContext, NativeVideoPlayerController)?` | `null` | Builder for custom overlay controls on top of the native player |

**Example:**
```dart
NativeVideoPlayer(
  controller: _controller,
  overlayBuilder: (context, controller) {
    return CustomVideoOverlay(controller: controller);
  },
)
```

### NativeVideoPlayerController

#### Methods

- `Future<void> initialize()` - Initialize the controller
- `Future<void> load({required String url, Map<String, String>? headers})` - Load video URL with optional HTTP headers
- `Future<void> play()` - Start playback
- `Future<void> pause()` - Pause playback
- `Future<void> seekTo(Duration position)` - Seek to position
- `Future<void> setVolume(double volume)` - Set volume (0.0-1.0)
- `Future<void> setSpeed(double speed)` - Set playback speed
- `Future<void> setQuality(NativeVideoPlayerQuality quality)` - Set video quality
- `Future<bool> isPictureInPictureAvailable()` - Check if PiP is available on device
- `Future<bool> enterPictureInPicture()` - Enter Picture-in-Picture mode
- `Future<bool> exitPictureInPicture()` - Exit Picture-in-Picture mode
- `Future<void> enterFullScreen()` - Enter fullscreen
- `Future<void> exitFullScreen()` - Exit fullscreen
- `Future<void> toggleFullScreen()` - Toggle fullscreen
- `Future<bool> isAirPlayAvailable()` - Check if AirPlay devices are available (iOS only)
- `Future<void> showAirPlayPicker()` - Show AirPlay device picker (iOS only)
- `void addAirPlayAvailabilityListener(void Function(bool) listener)` - Listen for AirPlay availability changes (iOS only)
- `void removeAirPlayAvailabilityListener(void Function(bool) listener)` - Remove AirPlay availability listener (iOS only)
- `void addAirPlayConnectionListener(void Function(bool) listener)` - Listen for AirPlay connection state changes (iOS only)
- `void removeAirPlayConnectionListener(void Function(bool) listener)` - Remove AirPlay connection listener (iOS only)
- `void addActivityListener(void Function(PlayerActivityEvent) listener)` - Add activity event listener
- `void removeActivityListener(void Function(PlayerActivityEvent) listener)` - Remove activity event listener
- `void addControlListener(void Function(PlayerControlEvent) listener)` - Add control event listener
- `void removeControlListener(void Function(PlayerControlEvent) listener)` - Remove control event listener
- `Future<void> dispose()` - Clean up resources

#### Properties

- `List<NativeVideoPlayerQuality> qualities` - Available HLS quality variants
- `bool isFullScreen` - Current fullscreen state
- `Duration currentPosition` - Current playback position
- `Duration duration` - Total video duration
- `Duration bufferedPosition` - How far the video has been buffered
- `double volume` - Current volume (0.0-1.0)
- `PlayerActivityState activityState` - Current activity state
- `PlayerControlState controlState` - Current control state
- `String? url` - Current video URL

### Activity Event States

| State | Description |
|-------|-------------|
| `PlayerActivityState.idle` | Player is idle |
| `PlayerActivityState.initializing` | Player is initializing |
| `PlayerActivityState.initialized` | Player initialized |
| `PlayerActivityState.loading` | Video is loading |
| `PlayerActivityState.loaded` | Video loaded successfully |
| `PlayerActivityState.playing` | Playback is active |
| `PlayerActivityState.paused` | Playback is paused |
| `PlayerActivityState.buffering` | Video is buffering |
| `PlayerActivityState.completed` | Playback completed |
| `PlayerActivityState.stopped` | Playback stopped |
| `PlayerActivityState.error` | Error occurred |

### Control Event States

| State | Description |
|-------|-------------|
| `PlayerControlState.none` | No control event |
| `PlayerControlState.qualityChanged` | Video quality changed |
| `PlayerControlState.speedChanged` | Playback speed changed |
| `PlayerControlState.seeked` | Seek operation completed |
| `PlayerControlState.pipStarted` | PiP mode started |
| `PlayerControlState.pipStopped` | PiP mode stopped |
| `PlayerControlState.fullscreenEntered` | Fullscreen entered |
| `PlayerControlState.fullscreenExited` | Fullscreen exited |
| `PlayerControlState.timeUpdated` | Playback time updated |

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

### Common Issues

**Controller not initializing:**
```dart
// Always call initialize() before load()
await _controller.initialize();
await _controller.load(url: 'https://example.com/video.m3u8');
```

**Events not firing:**
```dart
// Make sure to add listeners BEFORE calling initialize()
_controller.addActivityListener(_handleActivityEvent);
_controller.addControlListener(_handleControlEvent);
await _controller.initialize();
```

**Multiple controllers interfering:**
```dart
// Ensure each controller has a unique ID
final controller1 = NativeVideoPlayerController(id: 1);
final controller2 = NativeVideoPlayerController(id: 2);
```

**Memory leaks:**
```dart
// Always remove listeners and dispose controllers
@override
void dispose() {
  _controller.removeActivityListener(_handleActivityEvent);
  _controller.removeControlListener(_handleControlEvent);
  _controller.dispose();
  super.dispose();
}
```

### iOS

**Video doesn't play:**
- Ensure `Info.plist` has `NSAppTransportSecurity` configured for HTTP videos
- For HTTPS with self-signed certificates, add exception domains
- For local files, ensure proper file access permissions
- Check that the video format is supported by AVPlayer (HLS, MP4, MOV)

**PiP not working:**
- Enable Background Modes in Xcode: Target → Signing & Capabilities → Background Modes
- Check "Audio, AirPlay, and Picture in Picture"
- Ensure iOS version is 14.0+ (check with `await controller.isPictureInPictureAvailable()`)
- PiP requires video to be playing before entering PiP mode
- Some simulators don't support PiP; test on a physical device

**Now Playing not showing:**
```dart
// Provide mediaInfo when creating the controller
_controller = NativeVideoPlayerController(
  id: 1,
  mediaInfo: const NativeVideoPlayerMediaInfo(
    title: 'Video Title',
    subtitle: 'Artist Name',
  ),
);
```

**Background audio stops:**
- Verify Background Modes are enabled in Xcode capabilities
- Ensure "Audio, AirPlay, and Picture in Picture" is checked

### Android

**Video doesn't play:**
- Check internet permissions in your app's `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```
- Ensure minimum SDK version is 24+ in `build.gradle`:
```gradle
minSdkVersion 24
```
- For HTTPS issues, check your network security configuration
- Verify ExoPlayer supports the video format (HLS, MP4, WebM)

**PiP not working:**
- PiP requires Android 8.0+ (API 26+)
- Check device support: `await controller.isPictureInPictureAvailable()`
- Ensure your `AndroidManifest.xml` has the activity configured:
```xml
<activity
    android:name=".MainActivity"
    android:supportsPictureInPicture="true"
    android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation">
</activity>
```
- PiP events are automatically handled by the MainActivity
- Listen for PiP state changes using `PlayerControlState.pipStarted` and `PlayerControlState.pipStopped`

**Fullscreen issues:**
- The plugin handles fullscreen natively using a Dialog on Android
- Fullscreen works automatically; no additional configuration needed
- Ensure proper activity lifecycle management
- If orientation is locked, fullscreen may not rotate automatically

**Media notifications not showing:**
- The plugin automatically configures `MediaSessionService`
- Ensure foreground service permissions are granted (handled automatically)
- Media info must be provided via `mediaInfo` parameter
- Notifications appear when video is playing in background

**ExoPlayer errors:**
- Check logcat for detailed error messages
- Common issues:
  - Network timeouts: Check internet connectivity
  - Unsupported format: Verify video codec compatibility
  - DRM content: This plugin doesn't support DRM (yet)

### General Debugging

**Enable verbose logging:**
```dart
// Check player state
print('Activity State: ${_controller.activityState}');
print('Control State: ${_controller.controlState}');
print('Is Fullscreen: ${_controller.isFullScreen}');
print('Current Position: ${_controller.currentPosition}');
print('Duration: ${_controller.duration}');
```

**Test with known working URLs:**
```dart
// Apple's test HLS stream
const testUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

// Big Buck Bunny
const testUrl = 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
```

**Platform-specific issues:**
```dart
import 'dart:io';

if (Platform.isIOS) {
  // iOS-specific code
} else if (Platform.isAndroid) {
  // Android-specific code
}
```

## Example App

See the `example` folder for a complete working example demonstrating:

### Features Demonstrated
- **Video List with Inline Players**: Multiple video players in a scrollable list
- **Full-Screen Video Detail Page**: Dedicated page with comprehensive controls
- **Custom Overlay Controls**: Complete example of building custom video controls
- **AirPlay Integration**: AirPlay button with availability and connection tracking (iOS)
- **Playback Controls**: Play, pause, seek (±10 seconds), volume control
- **Speed Adjustment**: 0.25x, 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x playback speeds
- **Quality Selection**: Automatic quality detection and manual selection for HLS streams
- **Picture-in-Picture**: Enter/exit PiP mode with state tracking
- **Fullscreen Toggle**: Both native and Dart-side fullscreen support
- **Real-time Statistics**: Current position, duration, buffered position tracking
- **Separated Event Handling**: Activity and control events with detailed logging
- **Custom Media Info**: Now Playing integration with metadata
- **Buffered Position Indicator**: Visual representation of how much video has been preloaded

### Running the Example

```bash
cd example
flutter run
```

The example includes:
- `video_list_screen_with_players.dart` - Multiple inline video players
- `video_detail_screen_full.dart` - Full-featured video player with controls
- `video_with_overlay_screen.dart` - Custom overlay controls demonstration
- `custom_video_overlay.dart` - Complete custom overlay implementation with play/pause, progress bar, speed controls, quality selection, volume, AirPlay button, and auto-hide functionality
- `video_player_card.dart` - Reusable video player widget
- `video_item.dart` - Video model with sample HLS streams

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

Developed for the Flutter community. Based on native video player implementations using industry-standard libraries:
- iOS: AVFoundation
- Android: ExoPlayer (Media3)
