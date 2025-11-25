import 'package:flutter/material.dart';
import 'package:better_native_video_player/better_native_video_player.dart';

/// A modal bottom sheet for selecting audio tracks
class AudioPickerModal extends StatefulWidget {
  const AudioPickerModal({
    super.key,
    required this.controller,
  });

  final NativeVideoPlayerController controller;

  @override
  State<AudioPickerModal> createState() => _AudioPickerModalState();
}

class _AudioPickerModalState extends State<AudioPickerModal> {
  List<NativeVideoPlayerAudioTrack> _audioTracks = [];
  NativeVideoPlayerAudioTrack? _selectedTrack;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAudioTracks();
  }

  Future<void> _loadAudioTracks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tracks = await widget.controller.getAvailableAudioTracks();

      setState(() {
        _audioTracks = tracks;
        _selectedTrack = tracks.firstWhere(
          (track) => track.isSelected,
          orElse: () => NativeVideoPlayerAudioTrack.auto(),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio tracks: $e')),
        );
      }
    }
  }

  Future<void> _selectTrack(NativeVideoPlayerAudioTrack track) async {
    try {
      await widget.controller.setAudioTrack(track);
      setState(() {
        _selectedTrack = track;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              track.isAuto
                  ? 'Audio track set to auto'
                  : 'Selected: ${track.displayName}${track.codec != null ? " (${track.codec})" : ""}',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting audio track: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Audio Track',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Loading or track list
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_audioTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.audiotrack_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No audio tracks available',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  // Add "Auto" option at the top
                  _buildTrackTile(NativeVideoPlayerAudioTrack.auto()),

                  // List all available tracks
                  ..._audioTracks.map((track) => _buildTrackTile(track)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(NativeVideoPlayerAudioTrack track) {
    final isSelected = _selectedTrack?.index == track.index;

    return ListTile(
      leading: Radio<int>(
        value: track.index,
        groupValue: _selectedTrack?.index,
        onChanged: (value) => _selectTrack(track),
      ),
      title: Text(
        track.displayName,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
      ),
      subtitle: track.codec != null || track.language != 'auto'
          ? Text(
              '${track.language}${track.codec != null ? " • ${track.codec}" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () => _selectTrack(track),
    );
  }
}

/// Helper function to show the audio picker modal
Future<void> showAudioPicker(
  BuildContext context,
  NativeVideoPlayerController controller,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AudioPickerModal(controller: controller),
  );
}
