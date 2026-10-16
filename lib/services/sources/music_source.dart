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
  ResolvedStream(this.uri, {this.headers, this.cacheable = true}) : at = DateTime.now();

  bool get fresh => DateTime.now().difference(at) < const Duration(hours: 3);
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
    if (t.isLocal) {
      return t.uri == null ? null : ResolvedStream(Uri.parse(t.uri!), cacheable: false);
    }
    final s = forTrack(t);
    if (s == null) return null;
    try {
      return await s.resolve(t, quality: quality).timeout(const Duration(seconds: 25));
    } catch (_) {
      return null;
    }
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
