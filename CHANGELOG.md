# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
