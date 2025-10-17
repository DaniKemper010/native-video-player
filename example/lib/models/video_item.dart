class VideoItem {
  final int id;
  final String title;
  final String description;
  final String url;

  VideoItem({required this.id, required this.title, required this.description, required this.url});

  static List<VideoItem> getSampleVideos() {
    return [
      VideoItem(
        id: 1,
        title: 'Big Buck Bunny',
        description:
            'A large and lovable rabbit deals with three tiny bullies, led by a flying squirrel, who are determined to squelch his happiness.',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      ),
      VideoItem(
        id: 2,
        title: 'Elephant Dream',
        description:
            'The first open movie from the Blender Foundation. Two strange characters explore a capricious and seemingly infinite machine.',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      ),
      VideoItem(
        id: 3,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      ),
      VideoItem(
        id: 4,
        title: 'Tears of Steel',
        description:
            'A group of warriors and scientists unite to fight against a robot army and save the future of mankind.',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      ),
      VideoItem(
        id: 5,
        title: 'For Bigger Blazes',
        description: 'Experience the power and beauty of fire in stunning high definition quality.',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      ),
    ];
  }
}
