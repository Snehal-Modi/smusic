import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/formatters.dart';
import '../../models/track.dart';
import 'music_source.dart';

/// YouTube. No key. Unofficial, and YouTube blocks it often, so every call has a
/// second route through public Invidious / Piped servers. Patch here when it breaks.
class YoutubeSource extends MusicSource {
  final YoutubeExplode _yt = YoutubeExplode();

  static const _invidious = [
    'https://invidious.f5.si',
    'https://inv.nadeko.net',
    'https://yewtu.be',
    'https://invidious.nerdvpn.de',
  ];
  static const _piped = [
    'https://api.piped.private.coffee',
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
  ];
  static const _headers = {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36'};
  static const _alt = Duration(seconds: 8);

  @override
  TrackSource get kind => TrackSource.youtube;

  @override
  String get name => 'YouTube';

  Track _track(String id, String title, String author, Duration d) => Track(
        id: 'yt:$id',
        title: decodeHtml(title),
        artist: decodeHtml(author),
        album: 'YouTube',
        source: TrackSource.youtube,
        duration: d,
        artUrl: 'https://i.ytimg.com/vi/$id/mqdefault.jpg',
        extra: id,
      );

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    try {
      final res = await _yt.search.search(query).timeout(const Duration(seconds: 12));
      final out = <Track>[];
      for (final v in res) {
        if (out.length >= limit) break;
        final d = v.duration;
        if (d == null || d < const Duration(seconds: 30)) continue; // live / shorts
        if (d > const Duration(minutes: 25)) continue; // mixes / long videos
        out.add(_track(v.id.value, v.title, v.author, d));
      }
      if (out.isNotEmpty) return out;
    } catch (_) {}
    return _altSearch(query, limit);
  }

  Future<List<Track>> _altSearch(String query, int limit) async {
    final q = Uri.encodeQueryComponent(query);
    final tasks = <Future<List<Track>?>>[
      for (final h in _invidious) _guard(() => _invidiousSearch(h, q, limit)),
      for (final h in _piped) _guard(() => _pipedSearch(h, q, limit)),
    ];
    return await _firstNonEmpty<List<Track>>(tasks, (l) => l.isNotEmpty) ?? const [];
  }

  Future<List<Track>?> _invidiousSearch(String host, String q, int limit) async {
    final r = await http.get(Uri.parse('$host/api/v1/search?q=$q&type=video'), headers: _headers).timeout(_alt);
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    if (j is! List) return null;
    final out = <Track>[];
    for (final e in j) {
      if (out.length >= limit) break;
      if (e is! Map || e['videoId'] == null) continue;
      final secs = (e['lengthSeconds'] as num?)?.toInt() ?? 0;
      if (secs < 30 || secs > 25 * 60) continue;
      out.add(_track(e['videoId'].toString(), (e['title'] ?? '').toString(), (e['author'] ?? '').toString(), Duration(seconds: secs)));
    }
    return out;
  }

  Future<List<Track>?> _pipedSearch(String host, String q, int limit) async {
    final r = await http.get(Uri.parse('$host/search?q=$q&filter=videos'), headers: _headers).timeout(_alt);
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    final items = j is Map ? j['items'] : null;
    if (items is! List) return null;
    final out = <Track>[];
    for (final e in items) {
      if (out.length >= limit) break;
      if (e is! Map) continue;
      final url = (e['url'] ?? '').toString();
      final id = url.contains('v=') ? url.split('v=').last.split('&').first : '';
      if (id.isEmpty) continue;
      final secs = (e['duration'] as num?)?.toInt() ?? 0;
      if (secs < 30 || secs > 25 * 60) continue;
      out.add(_track(id, (e['title'] ?? '').toString(), (e['uploaderName'] ?? '').toString(), Duration(seconds: secs)));
    }
    return out;
  }

  @override
  Future<ResolvedStream?> resolve(Track t, {required StreamQuality quality}) async {
    final id = t.extra ?? t.id.replaceFirst('yt:', '');
    try {
      final rs = await _explode(id, quality).timeout(const Duration(seconds: 12));
      if (rs != null) return rs;
    } catch (_) {}
    final tasks = <Future<ResolvedStream?>>[
      for (final h in _invidious) _guard(() => _invidiousStream(h, id, quality)),
      for (final h in _piped) _guard(() => _pipedStream(h, id, quality)),
    ];
    return _firstNonEmpty<ResolvedStream>(tasks, (_) => true);
  }

  Future<ResolvedStream?> _explode(String id, StreamQuality quality) async {
    final manifest = await _yt.videos.streamsClient.getManifest(
      id,
      ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.ios, YoutubeApiClient.android],
    );
    final audios = manifest.audioOnly.toList();
    if (audios.isEmpty) {
      final muxed = manifest.muxed.toList();
      if (muxed.isEmpty) return null;
      muxed.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
      return ResolvedStream(muxed.first.url);
    }
    // Prefer mp4/aac (hardware decoding on most phones), else anything.
    final mp4 = audios.where((a) => a.container.name.toLowerCase().contains('mp4')).toList();
    final pool = mp4.isNotEmpty ? mp4 : audios;
    pool.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
    final AudioOnlyStreamInfo pick;
    switch (quality) {
      case StreamQuality.low:
        pick = pool.first;
        break;
      case StreamQuality.medium:
        pick = pool[pool.length ~/ 2];
        break;
      case StreamQuality.high:
        pick = pool.last;
        break;
    }
    return ResolvedStream(pick.url);
  }

  /// Picks an audio-only format from (url, mime, bitrate) candidates.
  ResolvedStream? _pick(List<(String, String, int)> c, StreamQuality quality) {
    if (c.isEmpty) return null;
    final mp4 = c.where((e) => e.$2.contains('mp4')).toList();
    final pool = mp4.isNotEmpty ? mp4 : c;
    pool.sort((a, b) => a.$3.compareTo(b.$3));
    final pick = quality == StreamQuality.low
        ? pool.first
        : quality == StreamQuality.medium
            ? pool[pool.length ~/ 2]
            : pool.last;
    // Signed links are tied to the server that made them: do not cache or reuse for long.
    return ResolvedStream(Uri.parse(pick.$1), cacheable: false, ttl: const Duration(minutes: 20));
  }

  Future<ResolvedStream?> _invidiousStream(String host, String id, StreamQuality quality) async {
    final r = await http.get(Uri.parse('$host/api/v1/videos/$id'), headers: _headers).timeout(_alt);
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    final formats = j is Map ? j['adaptiveFormats'] : null;
    if (formats is! List) return null;
    final c = <(String, String, int)>[];
    for (final f in formats) {
      if (f is! Map) continue;
      final type = (f['type'] ?? '').toString();
      final url = (f['url'] ?? '').toString();
      if (!type.startsWith('audio/') || url.isEmpty) continue;
      c.add((url, type, int.tryParse((f['bitrate'] ?? '0').toString()) ?? 0));
    }
    return _pick(c, quality);
  }

  Future<ResolvedStream?> _pipedStream(String host, String id, StreamQuality quality) async {
    final r = await http.get(Uri.parse('$host/streams/$id'), headers: _headers).timeout(_alt);
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    final streams = j is Map ? j['audioStreams'] : null;
    if (streams is! List) return null;
    final c = <(String, String, int)>[];
    for (final f in streams) {
      if (f is! Map) continue;
      final url = (f['url'] ?? '').toString();
      if (url.isEmpty) continue;
      c.add((url, (f['mimeType'] ?? '').toString(), (f['bitrate'] as num?)?.toInt() ?? 0));
    }
    return _pick(c, quality);
  }

  /// Runs [fn], turning any error into null.
  Future<T?> _guard<T>(Future<T?> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  /// Completes with the first result that [ok] accepts, or null when every task is done without one.
  Future<T?> _firstNonEmpty<T>(List<Future<T?>> tasks, bool Function(T) ok) {
    final done = Completer<T?>();
    var left = tasks.length;
    if (left == 0) return Future.value(null);
    for (final f in tasks) {
      f.then((v) {
        if (!done.isCompleted && v != null && ok(v)) done.complete(v);
      }).whenComplete(() {
        left--;
        if (left == 0 && !done.isCompleted) done.complete(null);
      });
    }
    return done.future;
  }

  @override
  Future<List<Track>> trending() async {
    try {
      return await search('new hindi songs this week', limit: 15);
    } catch (_) {
      return const [];
    }
  }
}
