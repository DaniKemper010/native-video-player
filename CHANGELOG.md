# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.4] - 2025-10-23

### Fixed
- **iOS Automatic Picture-in-Picture for Shared Controllers**: Fixed critical issue where automatic PiP would not work correctly when multiple views share the same controller (e.g., list view + detail view scenario)
  - Fixed race condition where multiple views observing the same shared player would compete for PiP control
  - Added primary view tracking to ensure only the most recently active view can trigger automatic PiP
  - Fixed automatic PiP not working for videos started with native controls (non-programmatic playback)
  - Improved SharedPlayerManager to properly handle PiP state transfers between views with the same controller ID
  - Added `isPrimaryView()` and `getPrimaryViewId()` methods to prevent observer conflicts

### Changed
- Enhanced observer logic to detect when playback starts via native controls and automatically set the view as primary
- Improved logging for debugging PiP state transitions across multiple views

## [0.2.3] - 2025-10-21

### Fixed
- Fixed Dart formatting issues in `native_video_player_controller.dart` and `fullscreen_manager.dart` to comply with pub.dev static analysis requirements

## [0.2.2] - 2025-10-21

### Added
- WASM compatibility: Package now supports Web Assembly (WASM) runtime
  - Implemented conditional imports using `dart:io` only on native platforms
  - Added `PlatformUtils` class for platform detection without direct `dart:io` dependency
  - Exported `PlatformUtils` for users who need platform-agnostic code

### Changed
- Replaced direct `Platform` checks with `PlatformUtils` in fullscreen manager and controller
- Code formatting improvements across all files

## [0.2.1] - 2025-10-21

### Fixed
- Updated iOS podspec version to match package version (0.2.1)

## [0.2.0] - 2025-10-21

### Added
- **AirPlay Support (iOS)**: Complete AirPlay integration for streaming to Apple TV and AirPlay-enabled devices
  - `isAirPlayAvailable()` method to check for available AirPlay devices
  - `showAirPlayPicker()` method to display native AirPlay device picker
  - `addAirPlayAvailabilityListener()` to monitor when AirPlay devices become available/unavailable
  - `addAirPlayConnectionListener()` to track AirPlay connection state changes
  - Automatic detection of AirPlay-enabled devices on the network
  - Support for streaming video to multiple AirPlay receivers

- **Custom Overlay Controls**: Build your own video player UI on top of the native player
  - New `overlayBuilder` parameter in `NativeVideoPlayer` widget
  - Full access to controller state for custom UI implementations
  - Allows building custom controls while maintaining native video decoding performance
  - Example implementation in `example/lib/widgets/custom_video_overlay.dart` with:
    - Play/pause control
    - Progress slider with buffered position indicator
    - Speed controls (0.25x - 2.0x)
    - Quality selector for HLS streams
    - Fullscreen toggle
    - Volume control
    - AirPlay button (iOS)
    - Auto-hide functionality

- **Dart-side Fullscreen Management**: New `FullscreenManager` class for Flutter-based fullscreen
  - `FullscreenVideoPlayer` widget for fullscreen video playback in a Flutter overlay
  - `enterFullscreen()` and `exitFullscreen()` methods
  - System UI management (hide/show status bar and navigation bar)
  - Device orientation locking options
  - Fullscreen dialog helper for easy integration
  - Works alongside native fullscreen for maximum flexibility

- **Buffered Position Tracking**: Real-time buffered position updates
  - New `bufferedPosition` property in controller
  - Included in `timeUpdated` control events
  - Enables showing how much video has been preloaded
  - Perfect for showing secondary progress indicator in custom overlays

### Improved
- Enhanced controller state management with better activity and control state tracking
- Improved fullscreen state synchronization between native and Dart layers
- Better event listener management with separate activity and control listeners
- Enhanced example app with new `video_with_overlay_screen.dart` demonstrating custom controls
- Improved documentation with comprehensive AirPlay and custom overlay usage examples
- Better error handling and state validation throughout the player lifecycle

### Documentation
- Updated README with comprehensive sections on AirPlay and custom overlays
- Added example code for all new features

## [0.1.4] - 2025-10-20

### Fixed
- Fixed Dart SDK constraint to use proper version range (>=3.9.0 <4.0.0) instead of exact version, allowing compatibility with all Dart 3.9.x and 3.x versions

## [0.1.3] - 2025-10-20

### Fixed
- Fixed fullscreen exit handling on iOS when user dismisses by swiping down or tapping Done button
- Fixed iOS playback state preservation when exiting fullscreen (video now resumes playing if it was playing before)
- Fixed Android fullscreen button icon synchronization when fullscreen is toggled from Flutter code
- Fixed fullscreen event parsing to properly distinguish between entering and exiting fullscreen states
- Fixed shared player state synchronization by sending current playback state when new views attach

### Improved
- Standardized event naming by renaming `videoLoaded` to `loaded` across all platforms for consistency
- Enhanced Android fullscreen button to detect and correct icon desynchronization
- Improved shared player initial state callback mechanism to properly communicate loaded state with duration
- Better fullscreen state event notifications on Android with proper `isFullscreen` data
- Enhanced iOS fullscreen delegate handling with playback state restoration

## [0.1.2] - 2025-01-16

### Fixed
- Fixed iOS player state tracking by observing `timeControlStatus` instead of relying only on item observers
- Fixed shared player initialization to properly handle existing players vs new players
- Fixed Android PiP event channel setup to only initialize on Android platform (prevents iOS errors)
- Fixed playback state synchronization when connecting to shared players
- Fixed unnecessary buffering/loading events for shared players during reattachment

### Improved
- Enhanced iOS player observer to distinguish between play/pause and buffering states
- Improved shared player management with better state tracking and event handling
- Enhanced Android player controls by hiding unnecessary buttons (next, previous, settings)
- Better error handling and logging throughout the player lifecycle

## [0.1.1] - 2025-10-20

### Fixed
- Fixed Android package name to match plugin name (com.huddlecommunity.better_native_video_player)
- Fixed plugin registration in Android

## [0.1.0] - 2025-10-20

### Changed
- Updated Flutter SDK constraint to 3.9.2
- Updated flutter_lints to 6.0.0

## [0.0.1] - 2025-01-16

### Added
- Initial release of native_video_player plugin
- Native video playback using AVPlayerViewController (iOS) and ExoPlayer/Media3 (Android)
- HLS streaming support with adaptive quality selection
- Picture-in-Picture (PiP) mode on both platforms
- Native fullscreen playback
- Now Playing integration (Control Center on iOS, lock screen on Android)
- Background playback with media notifications
- Comprehensive playback controls:
  - Play/pause
  - Seek to position
  - Volume control
  - Playback speed adjustment (0.5x to 2.0x)
  - Quality selection for HLS streams
- Event streaming for player state changes
- Support for custom media info (title, subtitle, album, artwork)
- Configurable PiP behavior
- Native player controls toggle
- Example app demonstrating all features
- Comprehensive documentation and API reference

### Platform Support
- iOS 12.0+
- Android API 24+ (Android 7.0+)

### Dependencies
- Flutter SDK ^3.9.2
- iOS: AVFoundation framework
- Android: androidx.media3 1.5.0 (ExoPlayer, HLS, Session)

[0.0.1]: https://github.com/DaniKemper010/native-video-player/releases/tag/v0.0.1
