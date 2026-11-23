enum ContentType {
  video('VIDEO', 'Video'),
  music('MUSIC', 'Nhạc'),
  podcast('PODCAST', 'Podcast'),
  post('POST', 'Post');

  const ContentType(this.apiValue, this.label);
  final String apiValue;
  final String label;
}
