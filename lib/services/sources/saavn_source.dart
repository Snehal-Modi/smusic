import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/formatters.dart';
import '../../models/track.dart';
import 'music_source.dart';

/// JioSaavn unofficial web API. Best for Indian music, up to 320 kbps.
/// Patch here when it breaks.
class SaavnSource extends MusicSource {
  static const _base = 'https://www.jiosaavn.com/api.php';
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
  };
  static const _timeout = Duration(seconds: 15);

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
    final r = await http
        .get(_u({'__call': 'search.getResults', 'q': query, 'p': '1', 'n': '$limit'}), headers: _headers)
        .timeout(_timeout);
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

  static String _bitrate(StreamQuality q) {
    switch (q) {
      case StreamQuality.low:
        return '96';
      case StreamQuality.medium:
        return '160';
      case StreamQuality.high:
        return '320';
    }
  }

  @override
  Future<ResolvedStream?> resolve(Track t, {required StreamQuality quality}) async {
    final enc = t.extra;
    if (enc == null) return null;
    final r = await http
        .get(_u({'__call': 'song.generateAuthToken', 'url': enc, 'bitrate': _bitrate(quality)}), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) return null;
    final j = _json(r.body);
    var url = (j is Map ? j['auth_url'] : null)?.toString();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://')) url = url.replaceFirst('http://', 'https://');

    // The signed link comes back on web.saavncdn.com, which answers 403 to
    // clients without browser headers. aac.saavncdn.com serves the same file
    // openly, so try it first and fall back to the original host.
    final alt = url.replaceAll(RegExp(r'//(web|ac\.cf)\.saavncdn\.com'), '//aac.saavncdn.com');
    for (final candidate in {alt, url}) {
      if (await _playable(candidate)) {
        return ResolvedStream(Uri.parse(candidate), headers: _streamHeaders);
      }
    }
    return null;
  }

  static const _streamHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
    'Referer': 'https://www.jiosaavn.com/',
  };

  /// Asks the CDN for the first byte so a dead link fails here, not in the player.
  Future<bool> _playable(String url) async {
    try {
      final r = await http
          .get(Uri.parse(url), headers: {..._streamHeaders, 'Range': 'bytes=0-0'})
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200 || r.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Track>> trending() async {
    try {
      final r = await http
          .get(_u({'__call': 'content.getTrending', 'entity_type': 'song', 'entity_language': 'hindi'}), headers: _headers)
          .timeout(_timeout);
      if (r.statusCode != 200) return const [];
      final j = _json(r.body);
      final list = j is List ? j : (j is Map ? (j['results'] ?? j['data']) as List? : null) ?? const [];
      return list
          .where((e) => e is Map && (e['type'] == 'song' || e['more_info'] != null))
          .map(_parse)
          .whereType<Track>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
