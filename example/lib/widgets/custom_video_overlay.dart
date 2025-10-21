import 'package:better_native_video_player/better_native_video_player.dart';
import 'package:flutter/material.dart';

/// Custom video overlay with controls
///
/// This widget provides custom playback controls that overlay on top of the native video player.
/// The visibility and fade animations are handled by the parent NativeVideoPlayer widget.
class CustomVideoOverlay extends StatefulWidget {
  const CustomVideoOverlay({required this.controller, super.key});

  final NativeVideoPlayerController controller;

  @override
  State<CustomVideoOverlay> createState() => _CustomVideoOverlayState();
}

class _CustomVideoOverlayState extends State<CustomVideoOverlay> {
  bool _isSeeking = false;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  PlayerActivityState _activityState = PlayerActivityState.idle;
  bool _isAirPlayAvailable = false;
  List<NativeVideoPlayerQuality> _qualities = [];
  NativeVideoPlayerQuality? _currentQuality;
  double _currentSpeed = 1.0;

  // Available playback speeds
  static const List<double> _availableSpeeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addActivityListener(_handleActivityEvent);
    widget.controller.addControlListener(_handleControlEvent);
    widget.controller.addAirPlayAvailabilityListener(
      _handleAirPlayAvailabilityChange,
    );

    // Get initial state
    _currentPosition = widget.controller.currentPosition;
    _duration = widget.controller.duration;
    _activityState = widget.controller.activityState;
    _qualities = widget.controller.qualities;

    debugPrint(
      'CustomVideoOverlay initialized with ${_qualities.length} qualities',
    );
  }

  void _handleAirPlayAvailabilityChange(bool isAvailable) {
    if (!mounted) {
      return;
    }
    debugPrint('AirPlay availability changed: $isAvailable');
    setState(() {
      _isAirPlayAvailable = isAvailable;
    });
  }

  @override
  void dispose() {
    widget.controller.removeActivityListener(_handleActivityEvent);
    widget.controller.removeControlListener(_handleControlEvent);
    widget.controller.removeAirPlayAvailabilityListener(
      _handleAirPlayAvailabilityChange,
    );
    super.dispose();
  }

  void _handleActivityEvent(PlayerActivityEvent event) {
    if (!mounted) {
      debugPrint(
        'CustomVideoOverlay._handleActivityEvent called but not mounted',
      );
      return;
    }
    debugPrint('CustomVideoOverlay._handleActivityEvent: ${event.state}');
    setState(() {
      _activityState = event.state;
    });
  }

  void _handleControlEvent(PlayerControlEvent event) {
    if (!mounted) {
      debugPrint(
        'CustomVideoOverlay._handleControlEvent called but not mounted',
      );
      return;
    }

    if (event.state == PlayerControlState.timeUpdated && !_isSeeking) {
      setState(() {
        _currentPosition = widget.controller.currentPosition;
        _duration = widget.controller.duration;
        _bufferedPosition = widget.controller.bufferedPosition;
      });
    } else if (event.state == PlayerControlState.qualityChanged) {
      // Update available qualities and current quality
      setState(() {
        _qualities = widget.controller.qualities;
        if (event.data != null && event.data!.containsKey('quality')) {
          _currentQuality = NativeVideoPlayerQuality.fromMap(
            event.data!['quality'] as Map<dynamic, dynamic>,
          );
        }
      });
    } else if (event.state == PlayerControlState.speedChanged) {
      // Update current speed when it changes (e.g., from another overlay instance)
      if (event.data != null && event.data!.containsKey('speed')) {
        final speed = event.data!['speed'] as num;
        debugPrint('CustomVideoOverlay: Speed changed to ${speed}x');
        setState(() {
          _currentSpeed = speed.toDouble();
        });
      }
    } else if (event.state == PlayerControlState.fullscreenEntered ||
        event.state == PlayerControlState.fullscreenExited) {
      // Trigger rebuild when fullscreen state changes so controls visibility updates
      debugPrint(
        'CustomVideoOverlay: Fullscreen state changed to ${widget.controller.isFullScreen}',
      );
      setState(() {
        // No state to update, just trigger rebuild to update conditional UI elements
      });
    } else if (event.state != PlayerControlState.timeUpdated) {
      debugPrint('CustomVideoOverlay._handleControlEvent: ${event.state}');
    }
  }

  void _onSeekStart(double value) {
    setState(() {
      _isSeeking = true;
      _currentPosition = Duration(milliseconds: value.toInt());
    });
  }

  void _onSeekChange(double value) {
    if (_isSeeking && _duration.inMilliseconds > 0) {
      setState(() {
        _currentPosition = Duration(milliseconds: value.toInt());
      });
    }
  }

  void _onSeekEnd(double value) {
    if (_duration.inMilliseconds > 0) {
      widget.controller.seekTo(Duration(milliseconds: value.toInt()));
    }
    setState(() {
      _isSeeking = false;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final stackWidget = Stack(
      children: [
        // Top controls
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Row(
            children: [
              // Back button (only when in fullscreen)
              if (widget.controller.isFullScreen)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    widget.controller.exitFullScreen();
                  },
                )
              else
                // Empty space when not in fullscreen to align AirPlay button to the right
                const SizedBox.shrink(),
              const Spacer(),
              // AirPlay button (only shown if available)
              if (_isAirPlayAvailable)
                IconButton(
                  icon: const Icon(Icons.airplay, color: Colors.white),
                  onPressed: () async {
                    await widget.controller.showAirPlayPicker();
                  },
                  tooltip: 'AirPlay',
                ),
            ],
          ),
        ),

        // Control buttons
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Skip backward
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                  widget.controller.seekTo(
                    _currentPosition - const Duration(seconds: 10),
                  );
                },
              ),

              // Center play/pause button
              _buildPlayPauseButton(),

              // Skip forward
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                  widget.controller.seekTo(
                    _currentPosition + const Duration(seconds: 10),
                  );
                },
              ),
            ],
          ),
        ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  spacing: 8,
                  children: [
                    Text(
                      _formatDuration(_currentPosition),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.red,
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.3,
                          ),
                          secondaryActiveTrackColor: Colors.white.withValues(
                            alpha: 0.5,
                          ),
                          thumbColor: Colors.red,
                          overlayColor: Colors.red.withValues(alpha: 0.3),
                        ),
                        child: Slider(
                          value: _duration.inMilliseconds > 0
                              ? _currentPosition.inMilliseconds
                                    .toDouble()
                                    .clamp(
                                      0.0,
                                      _duration.inMilliseconds.toDouble(),
                                    )
                              : 0.0,
                          secondaryTrackValue: _duration.inMilliseconds > 0
                              ? _bufferedPosition.inMilliseconds
                                    .toDouble()
                                    .clamp(
                                      0.0,
                                      _duration.inMilliseconds.toDouble(),
                                    )
                              : 0.0,
                          min: 0,
                          max: _duration.inMilliseconds > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 1.0,
                          onChangeStart: _onSeekStart,
                          onChanged: _onSeekChange,
                          onChangeEnd: _onSeekEnd,
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    // Speed control (only in fullscreen to avoid platform view disposal)
                    if (widget.controller.isFullScreen)
                      TextButton(
                        onPressed: _showSpeedSelector,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '${_currentSpeed}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    // Quality control (only in fullscreen to avoid platform view disposal)
                    if (widget.controller.isFullScreen && _qualities.isNotEmpty)
                      TextButton(
                        onPressed: _showQualitySelector,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _currentQuality?.label ?? 'Auto',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    // Fullscreen toggle
                    IconButton(
                      icon: Icon(
                        widget.controller.isFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        widget.controller.toggleFullScreen();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: widget.controller.isFullScreen
          ? SafeArea(child: stackWidget)
          : stackWidget,
    );
  }

  Widget _buildPlayPauseButton() {
    // Show loading indicator when buffering or loading
    if (_activityState == PlayerActivityState.buffering ||
        _activityState == PlayerActivityState.loading) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    // Show play/pause button for other states
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          _activityState.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 36,
        ),
        onPressed: () {
          debugPrint(
            'Play/Pause button pressed, isPlaying: ${_activityState.isPlaying}',
          );
          if (_activityState.isPlaying) {
            widget.controller.pause();
          } else {
            widget.controller.play();
          }
        },
      ),
    );
  }

  /// Shows the quality selector modal
  void _showQualitySelector() {
    // Only show in fullscreen mode
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      useRootNavigator: false,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Quality',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _qualities.map((quality) {
                    final isSelected = _currentQuality?.label == quality.label;
                    return ListTile(
                      title: Text(
                        quality.label,
                        style: TextStyle(
                          color: isSelected ? Colors.red : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: quality.bitrate != null
                          ? Text(
                              '${quality.width ?? '?'}x${quality.height ?? '?'} - ${(quality.bitrate! / 1000000).toStringAsFixed(2)} Mbps',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.red.withValues(alpha: 0.7)
                                    : Colors.white70,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.red)
                          : null,
                      onTap: () {
                        widget.controller.setQuality(quality);
                        Navigator.pop(context);
                        if (mounted) {
                          setState(() {
                            _currentQuality = quality;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows the speed selector modal
  void _showSpeedSelector() {
    // Only show in fullscreen mode
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      useRootNavigator: false,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Playback Speed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _availableSpeeds.map((speed) {
                    final isSelected = _currentSpeed == speed;
                    return ListTile(
                      title: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isSelected ? Colors.red : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        speed == 1.0
                            ? 'Normal'
                            : speed < 1.0
                            ? 'Slower'
                            : 'Faster',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.red.withValues(alpha: 0.7)
                              : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.red)
                          : null,
                      onTap: () async {
                        debugPrint('Setting speed to: $speed');
                        await widget.controller.setSpeed(speed);
                        debugPrint('Speed set successfully');
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (mounted) {
                          setState(() {
                            _currentSpeed = speed;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
