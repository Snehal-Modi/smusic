import '../../models/track.dart';
import 'audius_source.dart';
import 'radio_source.dart';
import 'saavn_source.dart';
import 'youtube_source.dart';

/// How much bandwidth a stream may use. Picked in Settings.
enum StreamQuality { low, medium, high }

StreamQuality streamQualityFrom(String? s) {
  for (final v in StreamQuality.values) {
    if (v.name == s) return v;
  }
  return StreamQuality.high;
}

String qualityLabel(StreamQuality q) {
  switch (q) {
    case StreamQuality.low:
      return 'Data saver';
    case StreamQuality.medium:
      return 'Balanced';
    case StreamQuality.high:
      return 'High';
  }
}

String qualityHint(StreamQuality q) {
  switch (q) {
    case StreamQuality.low:
      return 'About 96 kbps. Best for 2G / weak signal.';
    case StreamQuality.medium:
      return 'About 160 kbps. Good on 3G / busy Wi-Fi.';
    case StreamQuality.high:
      return 'Up to 320 kbps. Needs a steady connection.';
  }
}

class ResolvedStream {
  final Uri uri;
  final Map<String, String>? headers;
  final bool cacheable;
  final DateTime at;

  /// How long the link stays valid. Signed links (JioSaavn) die after minutes.
  final Duration ttl;

  ResolvedStream(this.uri, {this.headers, this.cacheable = true, this.ttl = const Duration(hours: 3)}) : at = DateTime.now();

  bool get fresh => DateTime.now().difference(at) < ttl;
}

abstract class MusicSource {
  TrackSource get kind;
  String get name;
  Future<List<Track>> search(String query, {int limit = 20});
  Future<ResolvedStream?> resolve(Track t, {required StreamQuality quality});
  Future<List<Track>> trending() async => const [];
}

/// All online sources in one place. Each one fails independently.
class Sources {
  Sources._();

  static final YoutubeSource youtube = YoutubeSource();
  static final SaavnSource saavn = SaavnSource();
  static final AudiusSource audius = AudiusSource();
  static final RadioSource radio = RadioSource();

  static List<MusicSource> get all => [saavn, youtube, audius, radio];

  static MusicSource? forTrack(Track t) {
    for (final s in all) {
      if (s.kind == t.source) return s;
    }
    return null;
  }

  static Future<ResolvedStream?> resolve(Track t, {required StreamQuality quality}) async {
    if (t.isLocal || t.isPodcast) {
      return t.uri == null ? null : ResolvedStream(Uri.parse(t.uri!), cacheable: false);
    }
    final s = forTrack(t);
    if (s == null) return null;
    try {
      final rs = await s.resolve(t, quality: quality).timeout(const Duration(seconds: 40));
      if (rs != null) return rs;
    } catch (_) {}
    // YouTube and Audius change often and some networks block them. When the
    // stream cannot be opened, play the same song from JioSaavn instead.
    if (t.source == TrackSource.youtube || t.source == TrackSource.audius) {
      return _viaSaavn(t, quality);
    }
    return null;
  }

  static const _noise = {
    'official', 'video', 'audio', 'lyrics', 'lyrical', 'full', 'song', 'songs', 'music', 'hd', '4k', 'new', 'latest',
    'with', 'feat', 'from', 'the', 'and', 'out', 'now',
  };

  static Set<String> _words(String s) {
    final cleaned = s.toLowerCase().replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ');
    return cleaned
        .split(RegExp(r'[^a-z0-9ऀ-ॿ]+'))
        .where((w) => w.length > 2 && !_noise.contains(w))
        .toSet();
  }

  static Future<ResolvedStream?> _viaSaavn(Track t, StreamQuality quality) async {
    try {
      final want = _words(t.title);
      if (want.isEmpty) return null;
      final query = t.source == TrackSource.audius ? '${t.title} ${t.artist}' : t.title;
      final hits = await saavn.search(query, limit: 6).timeout(const Duration(seconds: 12));
      final need = want.length <= 2 ? 1 : 2;
      for (final h in hits) {
        if (_words(h.title).intersection(want).length >= need) {
          final rs = await saavn.resolve(h, quality: quality).timeout(const Duration(seconds: 20));
          if (rs != null) return rs;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Runs the query on every source at the same time. Failures return empty.
  static Future<Map<TrackSource, List<Track>>> searchAll(String q, {Set<TrackSource>? only}) async {
    final targets = all.where((s) => only == null || only.contains(s.kind)).toList();
    final results = await Future.wait(targets.map((s) async {
      try {
        return await s.search(q).timeout(const Duration(seconds: 15));
      } catch (_) {
        return <Track>[];
      }
    }));
    final map = <TrackSource, List<Track>>{};
    for (int i = 0; i < targets.length; i++) {
      map[targets[i].kind] = results[i];
    }
    return map;
  }
}
