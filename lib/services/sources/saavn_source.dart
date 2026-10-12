import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/formatters.dart';
import '../../models/track.dart';
import 'music_source.dart';

/// JioSaavn unofficial web API. Best for Indian music, 320 kbps. Patch here when it breaks.
class SaavnSource extends MusicSource {
  static const _base = 'https://www.jiosaavn.com/api.php';
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
  };

  @override
  TrackSource get kind => TrackSource.saavn;

  @override
  String get name => 'JioSaavn';

  Uri _u(Map<String, String> q) => Uri.parse(_base).replace(queryParameters: {
        '_format': 'json',
        '_marker': '0',
        'api_version': '4',
        'ctx': 'web6dot0',
        ...q,
      });

  dynamic _json(String body) {
    // The endpoint sometimes prefixes junk before the JSON.
    final i = body.indexOf(RegExp(r'[\{\[]'));
    return jsonDecode(i <= 0 ? body : body.substring(i));
  }

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final r = await http.get(
      _u({'__call': 'search.getResults', 'q': query, 'p': '1', 'n': '$limit'}),
      headers: _headers,
    );
    if (r.statusCode != 200) return const [];
    final j = _json(r.body);
    final list = (j is Map ? j['results'] : null) as List? ?? const [];
    return list.map(_parse).whereType<Track>().toList();
  }

  Track? _parse(dynamic e) {
    try {
      final m = Map<String, dynamic>.from(e as Map);
      final info = Map<String, dynamic>.from((m['more_info'] ?? const {}) as Map);
      final enc = info['encrypted_media_url']?.toString();
      if (enc == null || enc.isEmpty) return null;
      String artist = '';
      final am = info['artistMap'];
      if (am is Map && am['primary_artists'] is List) {
        artist = (am['primary_artists'] as List).map((a) => decodeHtml(a['name'].toString())).join(', ');
      }
      if (artist.isEmpty) artist = decodeHtml((m['subtitle'] ?? '').toString());
      final secs = int.tryParse(info['duration']?.toString() ?? '') ?? 0;
      var img = (m['image'] ?? '').toString().replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');
      if (img.startsWith('http://')) img = img.replaceFirst('http://', 'https://');
      return Track(
        id: 'saavn:${m['id']}',
        title: decodeHtml((m['title'] ?? '').toString()),
        artist: artist,
        album: decodeHtml((info['album'] ?? m['title'] ?? '').toString()),
        source: TrackSource.saavn,
        duration: secs > 0 ? Duration(seconds: secs) : null,
        artUrl: img.isEmpty ? null : img,
        extra: enc,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ResolvedStream?> resolve(Track t, {required bool lowQuality}) async {
    final enc = t.extra;
    if (enc == null) return null;
    final r = await http.get(
      _u({'__call': 'song.generateAuthToken', 'url': enc, 'bitrate': lowQuality ? '96' : '320'}),
      headers: _headers,
    );
    if (r.statusCode != 200) return null;
    final j = _json(r.body);
    var url = (j is Map ? j['auth_url'] : null)?.toString();
    if (url == null || url.isEmpty) return null;
    url = url.replaceAll('ac.cf.saavncdn.com', 'aac.saavncdn.com');
    return ResolvedStream(Uri.parse(url));
  }

  @override
  Future<List<Track>> trending() async {
    try {
      final r = await http.get(
        _u({'__call': 'content.getTrending', 'entity_type': 'song', 'entity_language': 'hindi'}),
        headers: _headers,
      );
      if (r.statusCode != 200) return const [];
      final j = _json(r.body);
      final list = j is List ? j : (j is Map ? (j['results'] ?? j['data']) as List? : null) ?? const [];
      return list.where((e) => e is Map && (e['type'] == 'song' || e['more_info'] != null)).map(_parse).whereType<Track>().toList();
    } catch (_) {
      return const [];
    }
  }
}
