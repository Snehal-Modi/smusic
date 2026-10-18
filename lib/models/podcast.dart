/// A podcast show (or story series). Episodes are fetched from its RSS feed.
class Podcast {
  final String id;
  final String title;
  final String author;
  final String? artUrl;
  final String feedUrl;

  const Podcast({
    required this.id,
    required this.title,
    required this.author,
    required this.feedUrl,
    this.artUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'artUrl': artUrl,
        'feedUrl': feedUrl,
      };

  factory Podcast.fromJson(Map<String, dynamic> j) => Podcast(
        id: j['id'].toString(),
        title: (j['title'] ?? '') as String,
        author: (j['author'] ?? '') as String,
        artUrl: j['artUrl'] as String?,
        feedUrl: (j['feedUrl'] ?? '') as String,
      );

  @override
  bool operator ==(Object other) => other is Podcast && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
