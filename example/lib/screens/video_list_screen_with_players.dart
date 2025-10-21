import 'package:flutter/material.dart';

import '../models/video_item.dart';
import '../widgets/video_player_card.dart';
import 'video_detail_screen_full.dart';

class VideoListScreenWithPlayers extends StatelessWidget {
  const VideoListScreenWithPlayers({super.key});

  @override
  Widget build(BuildContext context) {
    final videos = VideoItem.getSampleVideos();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Video Gallery',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          // Use custom overlay for the first video to demonstrate inline custom controls
          final useCustomOverlay = index == 0;

          return VideoPlayerCard(
            video: video,
            useCustomOverlay: useCustomOverlay,
            onTap: (controller) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VideoDetailScreenFull(video: video, controller: controller, useCustomOverlay: useCustomOverlay),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
