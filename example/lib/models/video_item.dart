class VideoItem {
  final int id;
  final String title;
  final String description;
  final String url;
  final String artworkUrl;

  VideoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.artworkUrl,
  });

  static List<VideoItem> getSampleVideos() {
    return [
      VideoItem(
        id: 1,
        title: 'Big Buck Bunny',
        description:
            'A large and lovable rabbit deals with three tiny bullies, led by a flying squirrel, who are determined to squelch his happiness.',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        artworkUrl: 'https://picsum.photos/id/1/200/300',
      ),
      VideoItem(
        id: 2,
        title: 'Elephant Dream',
        description:
            'The first open movie from the Blender Foundation. Two strange characters explore a capricious and seemingly infinite machine.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
        artworkUrl: 'https://picsum.photos/id/2/200/300',
      ),
      VideoItem(
        id: 3,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/3/200/300',
      ),
      VideoItem(
        id: 4,
        title: 'Tears of Steel',
        description:
            'A group of warriors and scientists unite to fight against a robot army and save the future of mankind.',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        artworkUrl: 'https://picsum.photos/id/4/200/300',
      ),
      VideoItem(
        id: 5,
        title: 'For Bigger Blazes',
        description:
            'Experience the power and beauty of fire in stunning high definition quality.',
        url:
            'http://d3rlna7iyyu8wu.cloudfront.net/skip_armstrong/skip_armstrong_multichannel_subs.m3u8',
        artworkUrl: 'https://picsum.photos/id/5/200/300',
      ),
      VideoItem(
        id: 6,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/6/200/300',
      ),
      VideoItem(
        id: 7,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/7/200/300',
      ),
      VideoItem(
        id: 8,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/8/200/300',
      ),
      VideoItem(
        id: 9,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/9/200/300',
      ),
      VideoItem(
        id: 10,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/10/200/300',
      ),
      VideoItem(
        id: 11,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/11/200/300',
      ),
      VideoItem(
        id: 12,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/12/200/300',
      ),
      VideoItem(
        id: 13,
        title: 'Sintel',
        description:
            'A lonely young woman, Sintel, helps and befriends a dragon, whom she calls Scales. But when he is kidnapped by an adult dragon, Sintel decides to embark on a dangerous quest to find her lost friend.',
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.mp4/.m3u8',
        artworkUrl: 'https://picsum.photos/id/13/200/300',
      ),
    ];
  }
}
