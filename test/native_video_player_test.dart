import 'package:better_native_video_player/better_native_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NativeVideoPlayerController controller;
  late MethodChannel methodChannel;

  setUp(() {
    methodChannel = const MethodChannel('native_video_player');
    controller = NativeVideoPlayerController(
      id: 1,
      autoPlay: true,
      mediaInfo: NativeVideoPlayerMediaInfo(
        title: 'Test Video',
        subtitle: 'Test Subtitle',
        artworkUrl: 'https://example.com/artwork.jpg',
      ),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'load':
              return null;
            case 'play':
              return null;
            case 'pause':
              return null;
            case 'seekTo':
              return null;
            case 'setVolume':
              return null;
            case 'setSpeed':
              return null;
            case 'setQuality':
              return null;
            case 'getAvailableQualities':
              return [
                {
                  'label': '1080p',
                  'url': 'https://example.com/video_1080p.m3u8',
                },
                {'label': '720p', 'url': 'https://example.com/video_720p.m3u8'},
              ];
            case 'enterFullScreen':
              return null;
            case 'exitFullScreen':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    controller.dispose();
  });

  group('NativeVideoPlayerController initialization', () {
    test('should initialize correctly', () async {
      expect(controller.id, equals(1));
      expect(controller.autoPlay, isTrue);
      expect(controller.mediaInfo, isNotNull);
      expect(controller.mediaInfo?.title, equals('Test Video'));
      expect(controller.activityState.isLoaded, isFalse);
      expect(controller.url, isNull);
    });

    test('should not be loaded before load() is called', () {
      expect(controller.activityState.isLoaded, isFalse);
    });
  });

  group('NativeVideoPlayerController loading', () {
    test('should load video correctly', () async {
      await controller.initialize();
      await controller.load(url: 'https://example.com/video.m3u8');
      expect(controller.activityState.isLoaded, isTrue);
      expect(controller.url, equals('https://example.com/video.m3u8'));
    });

    test('should throw if load() is called before initialize()', () async {
      expect(
        () => controller.load(url: 'https://example.com/video.m3u8'),
        throwsException,
      );
    });

    test('should load with headers', () async {
      await controller.initialize();
      await controller.load(
        url: 'https://example.com/video.m3u8',
        headers: {'Referer': 'https://example.com'},
      );
      expect(controller.activityState.isLoaded, isTrue);
    });
  });

  group('NativeVideoPlayerController playback controls', () {
    setUp(() async {
      await controller.initialize();
      await controller.load(url: 'https://example.com/video.m3u8');
    });

    test('should play video', () async {
      await controller.play();
      // Verify through method channel call
    });

    test('should pause video', () async {
      await controller.pause();
      // Verify through method channel call
    });

    test('should seek to position', () async {
      await controller.seekTo(const Duration(seconds: 30));
      // Verify through method channel call
    });

    test('should set volume', () async {
      await controller.setVolume(0.5);
      // Verify through method channel call
    });

    test('should set playback speed', () async {
      await controller.setSpeed(1.5);
      // Verify through method channel call
    });
  });

  group('NativeVideoPlayerController quality control', () {
    setUp(() async {
      await controller.initialize();
      await controller.load(url: 'https://example.com/video.m3u8');
    });

    test('should fetch available qualities', () async {
      expect(controller.qualities.length, equals(2));
      expect(controller.qualities.first.label, equals('1080p'));
      expect(controller.qualities.last.label, equals('720p'));
    });

    test('should set quality', () async {
      final quality = controller.qualities.first;
      await controller.setQuality(quality);
      // Verify through method channel call
    });
  });

  group('NativeVideoPlayerController fullscreen control', () {
    setUp(() async {
      await controller.initialize();
      await controller.load(url: 'https://example.com/video.m3u8');
    });

    test('should enter fullscreen', () async {
      expect(controller.isFullScreen, isFalse);
      await controller.enterFullScreen();
      expect(controller.isFullScreen, isTrue);
    });

    test('should exit fullscreen', () async {
      await controller.enterFullScreen();
      expect(controller.isFullScreen, isTrue);
      await controller.exitFullScreen();
      expect(controller.isFullScreen, isFalse);
    });

    test('should toggle fullscreen', () async {
      expect(controller.isFullScreen, isFalse);
      await controller.toggleFullScreen();
      expect(controller.isFullScreen, isTrue);
      await controller.toggleFullScreen();
      expect(controller.isFullScreen, isFalse);
    });
  });

  group('NativeVideoPlayerController event handling', () {
    late List<PlayerActivityEvent> receivedEvents;

    setUp(() async {
      receivedEvents = [];
      await controller.initialize();
      controller.addActivityListener((event) => receivedEvents.add(event));
    });

    test('should handle player events', () async {
      // Simulate event from native side
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'native_video_player_1',
            const StandardMethodCodec().encodeSuccessEnvelope({
              'event': 'play',
              'position': 0,
            }),
            (ByteData? data) {},
          );

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.state, equals(PlayerActivityState.playing));
    });
  });
}
