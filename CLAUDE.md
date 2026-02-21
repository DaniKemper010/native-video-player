# CLAUDE.md

## Project Overview

**better_native_video_player** is a Flutter plugin (v0.4.11) that provides native video playback using AVPlayerViewController on iOS and ExoPlayer (Media3) on Android. It supports HLS streaming, Picture-in-Picture, AirPlay, fullscreen, DRM, background playback, and media notifications.

- **License:** MIT
- **Dart SDK:** >=3.9.0 <4.0.0
- **Flutter:** >=3.3.0
- **Android min SDK:** 24 (Android 7.0+), compile/target SDK 36
- **iOS min version:** 12.0
- **Swift:** 5.0, **Kotlin:** 2.1.0, **Java:** 11

## Repository Structure

```
/
├── lib/                              # Dart plugin source
│   ├── better_native_video_player.dart  # Library entry point (exports)
│   └── src/
│       ├── controllers/              # NativeVideoPlayerController (~2,467 lines)
│       ├── models/                   # State, Quality, SubtitleTrack, MediaInfo
│       ├── enums/                    # PlayerActivityState, PlayerControlState, events
│       ├── platform/                 # Method channel + platform utils
│       ├── fullscreen/               # Fullscreen manager and widget
│       ├── services/                 # AirPlayStateManager
│       └── native_video_player_widget.dart
├── android/                          # Android native (Kotlin)
│   ├── build.gradle                  # Gradle config (Media3/ExoPlayer 1.5.0)
│   └── src/main/kotlin/.../
│       ├── NativeVideoPlayerPlugin.kt
│       ├── VideoPlayerView.kt        # PlatformView implementation
│       ├── VideoPlayerMediaSessionService.kt
│       ├── handlers/                 # Method, Event, Observer, Quality, Notification
│       └── manager/                  # SharedPlayerManager
├── ios/                              # iOS native (Swift)
│   ├── better_native_video_player.podspec
│   └── Classes/
│       ├── View/                     # VideoPlayerView
│       ├── Handlers/                 # Method, Observer, Quality, NowPlaying, DRM, EventChannel
│       ├── Manager/                  # SharedPlayerManager
│       ├── Factory/                  # VideoPlayerViewFactory
│       ├── Extensions/               # ViewController delegates
│       └── Models/                   # VideoPlayerModels
├── example/                          # Example Flutter app
│   ├── lib/                          # Screens, widgets, models
│   ├── android/                      # Example Android project
│   └── ios/                          # Example iOS project
├── test/                             # Dart unit/widget tests
├── pubspec.yaml                      # Package manifest
└── analysis_options.yaml             # Lint config (flutter_lints)
```

## Build & Development Commands

### Dart/Flutter

```bash
# Get dependencies
flutter pub get

# Run tests
flutter test

# Analyze code (linting)
flutter analyze

# Format code
dart format .

# Run example app
cd example && flutter run
```

### Android

```bash
# Build Android native (from example/)
cd example && flutter build apk

# Run Android unit tests
cd android && ./gradlew test
```

### iOS

```bash
# Install pods (from example/ios/)
cd example/ios && pod install

# Build iOS (from example/)
cd example && flutter build ios --no-codesign
```

## Architecture

### Platform Communication

The plugin uses Flutter's **Method Channel** (`native_video_player`) for Dart-to-native communication and **Event Channels** (`native_video_player_{controllerId}`) for native-to-Dart event streaming. Each controller instance has a unique numeric ID and a dedicated event channel.

### Key Architectural Patterns

- **Handler pattern:** Both iOS and Android separate concerns into handler classes (MethodHandler, EventHandler/Observer, QualityHandler, etc.)
- **SharedPlayerManager:** Singleton on both platforms that manages player instances by controller ID, enabling multiple simultaneous players
- **Separated events:** Activity events (play, pause, buffering, error) and control events (volume, speed, quality change) use distinct listener APIs
- **Individual property streams:** Position, duration, volume, speed, etc. each have dedicated `ValueNotifier`-based streams

### Controller Lifecycle

1. Create `NativeVideoPlayerController` with a unique `id`
2. Call `controller.initialize()` to set up the platform view and event channel
3. Call `controller.load(url: ...)` to load media
4. Use playback methods: `play()`, `pause()`, `seekTo()`, etc.
5. Call `controller.dispose()` to release native resources

### Native Implementations

- **iOS:** Uses `AVPlayerViewController` embedded via `FlutterPlatformView`. Native fullscreen, PiP, AirPlay, and Now Playing integration via AVKit/AVFoundation/MediaPlayer frameworks.
- **Android:** Uses ExoPlayer (Media3 v1.5.0) with `PlayerView` embedded via `PlatformView`. Media session service for background playback and notification controls. PiP via the `floating` package.

## Dependencies

### Dart
- `dismissible_page: ^1.0.2` — Swipe-to-dismiss fullscreen
- `floating: ^6.0.0` — Android Picture-in-Picture

### Android (Gradle)
- `androidx.media3:media3-exoplayer:1.5.0`
- `androidx.media3:media3-ui:1.5.0`
- `androidx.media3:media3-exoplayer-hls:1.5.0`
- `androidx.media3:media3-session:1.5.0`
- `androidx.media:media:1.7.0`

### iOS
- AVFoundation, AVKit, MediaPlayer (system frameworks)

## Testing

Tests are located in `/test/`:

- `native_video_player_test.dart` — Controller initialization, loading, playback, quality, fullscreen, and event handling tests
- `native_video_player_method_channel_test.dart` — Method channel communication tests
- `native_video_player_widget_test.dart` — Widget rendering tests

Run all tests:
```bash
flutter test
```

## Code Conventions

### Dart
- Follow `flutter_lints` rules (defined in `analysis_options.yaml`)
- Format with `dart format .` before committing
- Use `debugPrint()` for error logging (not `print()`)
- Method channel errors are silently caught in most cases to prevent crashes
- All public API methods include `///` doc comments

### Naming
- Dart files: `snake_case.dart`
- Dart classes: `PascalCase` prefixed with `NativeVideoPlayer` (e.g., `NativeVideoPlayerController`, `NativeVideoPlayerState`)
- Kotlin files: `PascalCase.kt`
- Swift files: `PascalCase.swift`

### Method Channel Protocol
- Channel name: `native_video_player`
- Event channel pattern: `native_video_player_{controllerId}`
- All method calls include a `viewId` parameter to identify the controller
- Method names are camelCase strings (e.g., `load`, `play`, `seekTo`, `setVolume`, `getAvailableQualities`)

### Platform Code Organization
- Both iOS and Android follow a handler/manager/view separation
- Handlers process incoming method calls and outgoing events
- Managers hold shared player instance state
- Views manage the platform view lifecycle

## Key Features for Reference

- HLS streaming with adaptive quality selection
- Multiple video formats (HLS, MP4, WebM, MKV, MOV)
- Picture-in-Picture (iOS native, Android via `floating` package)
- AirPlay with device detection (iOS)
- Fullscreen (native iOS, Dart-based with swipe-to-dismiss)
- DRM support (FairPlay iOS, Widevine Android, AES-128, ClearKey)
- Background playback with media notifications
- Now Playing / Control Center integration
- Multiple simultaneous controller instances
- Custom HTTP headers
- Subtitle/closed caption support
- Custom overlay widgets
