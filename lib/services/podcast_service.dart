import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/formatters.dart';
import '../models/podcast.dart';
import '../models/track.dart';

/// Podcasts and spoken stories. Shows come from Apple's free podcast directory
/// (no key), episodes from each show's public RSS feed.
class PodcastService {
  static const _timeout = Duration(seconds: 18);
  static const _headers = {'User-Agent': 'smusic/1.2 (personal music player)'};

  final Map<String, List<Track>> _episodes = {};
  List<Podcast>? _top;

  /// Browse chips: label and the search used for it.
  static const categories = <(String, String)>[
    ('Stories', 'kahani stories'),
    ('Bedtime', 'bedtime stories'),
    ('Comedy', 'comedy'),
    ('True crime', 'true crime'),
    ('News', 'news'),
    ('Devotional', 'bhakti devotional'),
    ('Motivation', 'motivation'),
    ('Business', 'business'),
    ('Kids', 'kids stories'),
    ('Music', 'music'),
  ];

  Podcast? _fromResult(dynamic e) {
    try {
      final m = Map<String, dynamic>.from(e as Map);
      final feed = (m['feedUrl'] ?? '').toString();
      if (feed.isEmpty) return null;
      final art = (m['artworkUrl600'] ?? m['artworkUrl100'] ?? '').toString();
      return Podcast(
        id: (m['collectionId'] ?? m['trackId'] ?? feed).toString(),
        title: decodeHtml((m['collectionName'] ?? m['trackName'] ?? 'Podcast').toString()),
        author: decodeHtml((m['artistName'] ?? '').toString()),
        feedUrl: feed,
        artUrl: art.isEmpty ? null : art,
      );
    } catch (_) {
      return null;
    }
  }

  /// Most popular shows in India right now.
  Future<List<Podcast>> top({int limit = 20, bool force = false}) async {
    if (_top != null && !force) return _top!;
    try {
      final r = await http
          .get(Uri.parse('https://itunes.apple.com/in/rss/toppodcasts/limit=$limit/json'), headers: _headers)
          .timeout(_timeout);
      if (r.statusCode != 200) return const [];
      final j = jsonDecode(r.body);
      final entries = (j is Map ? (j['feed'] as Map?)?['entry'] : null) as List? ?? const [];
      final ids = <String>[];
      for (final e in entries) {
        final id = ((e as Map)['id'] as Map?)?['attributes']?['im:id'];
        if (id != null) ids.add(id.toString());
      }
      if (ids.isEmpty) return const [];
      // The chart has no feed urls; one lookup call fetches them all.
      final l = await http
          .get(Uri.parse('https://itunes.apple.com/lookup?id=${ids.join(',')}&entity=podcast'), headers: _headers)
          .timeout(_timeout);
      if (l.statusCode != 200) return const [];
      final results = (jsonDecode(l.body)['results'] as List?) ?? const [];
      final out = results.map(_fromResult).whereType<Podcast>().toList();
      if (out.isNotEmpty) _top = out;
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Podcast>> search(String query, {int limit = 25}) async {
    try {
      final r = await http
          .get(
              Uri.parse(
                  'https://itunes.apple.com/search?media=podcast&entity=podcast&country=IN&limit=$limit&term=${Uri.encodeQueryComponent(query)}'),
              headers: _headers)
          .timeout(_timeout);
      if (r.statusCode != 200) return const [];
      final results = (jsonDecode(r.body)['results'] as List?) ?? const [];
      return results.map(_fromResult).whereType<Podcast>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Latest episodes of a show, newest first. Throws when the feed cannot be read.
  Future<List<Track>> episodes(Podcast p, {int limit = 60}) async {
    final cached = _episodes[p.feedUrl];
    if (cached != null) return cached;
    final r = await http.get(Uri.parse(p.feedUrl), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('feed ${r.statusCode}');
    final list = _parse(p, utf8.decode(r.bodyBytes, allowMalformed: true), limit);
    if (list.isNotEmpty) _episodes[p.feedUrl] = list;
    return list;
  }

  List<Track> _parse(Podcast p, String xml, int limit) {
    final out = <Track>[];
    for (final m in RegExp(r'<item[\s>][\s\S]*?</item>').allMatches(xml)) {
      if (out.length >= limit) break;
      final item = m.group(0)!;
      final url = _attr(item, 'enclosure', 'url');
      if (url == null || !url.startsWith('http')) continue;
      final img = _attr(item, 'itunes:image', 'href');
      out.add(Track(
        id: 'pod:${_fnv(url)}',
        title: _text(item, 'title') ?? 'Episode',
        artist: p.title,
        album: p.author.isEmpty ? 'Podcast' : p.author,
        source: TrackSource.podcast,
        duration: _duration(_text(item, 'itunes:duration')),
        uri: url,
        artUrl: img ?? p.artUrl,
      ));
    }
    return out;
  }

  static String? _text(String item, String tag) {
    final m = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>').firstMatch(item);
    if (m == null) return null;
    var s = m.group(1)!.trim();
    if (s.startsWith('<![CDATA[')) {
      s = s.substring(9);
      if (s.endsWith(']]>')) s = s.substring(0, s.length - 3);
    }
    s = decodeHtml(s.trim());
    return s.isEmpty ? null : s;
  }

  static String? _attr(String item, String tag, String attr) {
    final m = RegExp('<$tag\\b[^>]*?\\b$attr=["\']([^"\']+)["\']').firstMatch(item);
    return m?.group(1)?.replaceAll('&amp;', '&');
  }

  static Duration? _duration(String? s) {
    if (s == null) return null;
    final parts = s.split(':').map((e) => int.tryParse(e.trim())).toList();
    if (parts.isEmpty || parts.any((e) => e == null)) return null;
    final v = parts.cast<int>();
    int secs;
    if (v.length == 3) {
      secs = v[0] * 3600 + v[1] * 60 + v[2];
    } else if (v.length == 2) {
      secs = v[0] * 60 + v[1];
    } else {
      secs = v[0];
    }
    return secs > 0 ? Duration(seconds: secs) : null;
  }

  /// Small stable hash so an episode keeps the same id between launches.
  static String _fnv(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }
}
