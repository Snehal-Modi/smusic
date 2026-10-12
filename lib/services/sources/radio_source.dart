import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/track.dart';
import 'music_source.dart';

/// Internet radio via radio-browser.info (community API, no key).
class RadioSource extends MusicSource {
  static const _hosts = [
    'https://de1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
  ];
  static const _headers = {'User-Agent': 'smusic/1.0'};

  @override
  TrackSource get kind => TrackSource.radio;

  @override
  String get name => 'Radio';

  Future<List<dynamic>> _get(String path) async {
    for (final h in _hosts) {
      try {
        final r = await http.get(Uri.parse('$h$path'), headers: _headers).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final j = jsonDecode(r.body);
          if (j is List) return j;
        }
      } catch (_) {}
    }
    return const [];
  }

  Track? _parse(dynamic e) {
    try {
      final m = Map<String, dynamic>.from(e as Map);
      final url = (m['url_resolved'] ?? m['url'] ?? '').toString();
      if (url.isEmpty) return null;
      final tags = (m['tags'] ?? '').toString().split(',').where((s) => s.trim().isNotEmpty).take(3).join(', ');
      final country = (m['country'] ?? '').toString();
      final fav = (m['favicon'] ?? '').toString();
      return Track(
        id: 'radio:${m['stationuuid']}',
        title: (m['name'] ?? 'Radio').toString().trim(),
        artist: [country, tags].where((s) => s.isNotEmpty).join(' / '),
        album: 'Live radio',
        source: TrackSource.radio,
        uri: url,
        artUrl: fav.startsWith('http') ? fav : null,
        extra: (m['codec'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final list = await _get(
        '/json/stations/search?name=${Uri.encodeQueryComponent(query)}&limit=$limit&hidebroken=true&order=clickcount&reverse=true');
    return list.map(_parse).whereType<Track>().toList();
  }

  @override
  Future<ResolvedStream?> resolve(Track t, {required bool lowQuality}) async {
    if (t.uri == null) return null;
    return ResolvedStream(Uri.parse(t.uri!), cacheable: false);
  }

  @override
  Future<List<Track>> trending() async {
    final list = await _get('/json/stations/bycountrycodeexact/IN?order=clickcount&reverse=true&limit=20&hidebroken=true');
    final india = list.map(_parse).whereType<Track>().toList();
    if (india.length >= 8) return india;
    final world = await _get('/json/stations/topclick/20?hidebroken=true');
    return [...india, ...world.map(_parse).whereType<Track>()];
  }
}
