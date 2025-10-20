# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
