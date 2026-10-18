import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/track.dart';
import 'music_source.dart';

/// Audius: free, legal, open API. No key, only an app name.
class AudiusSource extends MusicSource {
  static const _app = 'smusic';
  static const _timeout = Duration(seconds: 12);
  String? _host;

  @override
  TrackSource get kind => TrackSource.audius;

  @override
  String get name => 'Audius';

  Future<String> _hostUrl() async {
    if (_host != null) return _host!;
    try {
      final r = await http.get(Uri.parse('https://api.audius.co')).timeout(const Duration(seconds: 10));
      final j = jsonDecode(r.body);
      final hosts = (j['data'] as List?) ?? const [];
      if (hosts.isNotEmpty) _host = hosts.first.toString();
    } catch (_) {}
    _host ??= 'https://discoveryprovider.audius.co';
    return _host!;
  }

  Track? _parse(dynamic e) {
    try {
      final m = Map<String, dynamic>.from(e as Map);
      final art = m['artwork'] is Map ? Map<String, dynamic>.from(m['artwork'] as Map) : const <String, dynamic>{};
      final secs = (m['duration'] as num?)?.toInt() ?? 0;
      return Track(
        id: 'audius:${m['id']}',
        title: (m['title'] ?? '').toString(),
        artist: ((m['user'] ?? const {})['name'] ?? 'Audius artist').toString(),
        album: 'Audius',
        source: TrackSource.audius,
        duration: secs > 0 ? Duration(seconds: secs) : null,
        artUrl: (art['480x480'] ?? art['150x150'])?.toString(),
        extra: m['id'].toString(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final host = await _hostUrl();
    final r = await http
        .get(Uri.parse('$host/v1/tracks/search?query=${Uri.encodeQueryComponent(query)}&app_name=$_app'))
        .timeout(_timeout);
    if (r.statusCode != 200) {
      _host = null; // try another discovery node next time
      return const [];
    }
    final list = (jsonDecode(r.body)['data'] as List?) ?? const [];
    return list.map(_parse).whereType<Track>().take(limit).toList();
  }

  @override
  Future<ResolvedStream?> resolve(Track t, {required StreamQuality quality}) async {
    // Audius serves one quality per track; nothing to pick.
    final host = await _hostUrl();
    return ResolvedStream(Uri.parse('$host/v1/tracks/${t.extra}/stream?app_name=$_app'));
  }

  @override
  Future<List<Track>> trending() async {
    try {
      final host = await _hostUrl();
      final r = await http.get(Uri.parse('$host/v1/tracks/trending?app_name=$_app')).timeout(_timeout);
      if (r.statusCode != 200) return const [];
      final list = (jsonDecode(r.body)['data'] as List?) ?? const [];
      return list.map(_parse).whereType<Track>().take(20).toList();
    } catch (_) {
      return const [];
    }
  }
}
