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
      final lang = (m['language'] ?? '').toString().toLowerCase().trim();
      return Track(
        id: 'saavn:${m['id']}',
        title: decodeHtml((m['title'] ?? '').toString()),
        artist: artist,
        album: decodeHtml((info['album'] ?? m['title'] ?? '').toString()),
        source: TrackSource.saavn,
        duration: secs > 0 ? Duration(seconds: secs) : null,
        artUrl: img.isEmpty ? null : img,
        extra: enc,
        lang: lang.isEmpty ? null : lang,
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
        return ResolvedStream(Uri.parse(candidate), headers: _streamHeaders, ttl: _ttl(candidate));
      }
    }
    return null;
  }

  /// The signed link carries its own expiry (a few minutes). Remember it so a
  /// stale link is never reused for replays or the next-track prefetch.
  static Duration _ttl(String url) {
    final m = RegExp(r'[?&]Expires=(\d+)').firstMatch(url);
    if (m == null) return const Duration(minutes: 3);
    final exp = int.tryParse(m.group(1)!) ?? 0;
    final left = exp - DateTime.now().millisecondsSinceEpoch ~/ 1000 - 20;
    return Duration(seconds: left.clamp(0, 6 * 3600).toInt());
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
  Future<List<Track>> trending() => trendingIn('hindi');

  /// Songs from a Saavn playlist id (charts, curated lists).
  Future<List<Track>> playlistSongs(String id, {int count = 40}) async {
    try {
      final r = await http
          .get(_u({'__call': 'playlist.getDetails', 'listid': id, 'n': '$count', 'p': '1'}), headers: _headers)
          .timeout(_timeout);
      if (r.statusCode != 200) return const [];
      final j = _json(r.body);
      final list = (j is Map ? j['list'] : null) as List? ?? const [];
      return list.map(_parse).whereType<Track>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// "Top 50" chart for a language, found through playlist search.
  Future<List<Track>> chart(String language) async {
    try {
      final r = await http
          .get(_u({'__call': 'search.getPlaylistResults', 'q': '$language top 50', 'p': '1', 'n': '5'}), headers: _headers)
          .timeout(_timeout);
      if (r.statusCode != 200) return const [];
      final j = _json(r.body);
      final list = (j is Map ? j['results'] : null) as List? ?? const [];
      for (final e in list) {
        if (e is Map && (e['title'] ?? '').toString().toLowerCase().contains(language.toLowerCase())) {
          final songs = await playlistSongs(e['id'].toString());
          if (songs.isNotEmpty) return songs;
        }
      }
    } catch (_) {}
    return const [];
  }

  /// Songs in the style of an artist: JioSaavn's own artist radio, which is what
  /// makes "more like this" work. Falls back to a plain search.
  Future<List<Track>> artistRadio(String artist, {String language = 'hindi', int count = 20}) async {
    try {
      final sr = await http
          .get(_u({'__call': 'webradio.createArtistStation', 'name': artist, 'query': artist, 'language': language}),
              headers: _headers)
          .timeout(_timeout);
      if (sr.statusCode == 200) {
        final sj = _json(sr.body);
        final sid = (sj is Map ? sj['stationid'] : null)?.toString();
        if (sid != null && sid.isNotEmpty) {
          final r = await http
              .get(_u({'__call': 'webradio.getSong', 'stationid': sid, 'k': '$count'}), headers: _headers)
              .timeout(_timeout);
          if (r.statusCode == 200) {
            final j = _json(r.body);
            final out = <Track>[];
            if (j is Map) {
              for (final e in j.entries) {
                final v = e.value;
                if (e.key == 'stationid' || v is! Map || v['song'] == null) continue;
                final t = _parse(v['song']);
                if (t != null) out.add(t);
              }
            }
            if (out.isNotEmpty) return out;
          }
        }
      }
    } catch (_) {}
    try {
      return await search(artist, limit: count);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Track>> trendingIn(String language) async {
    try {
      final r = await http
          .get(_u({'__call': 'content.getTrending', 'entity_type': 'song', 'entity_language': language}), headers: _headers)
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
