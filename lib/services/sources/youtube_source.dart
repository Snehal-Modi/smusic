import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/track.dart';
import 'music_source.dart';

/// YouTube via youtube_explode_dart. No key. Unofficial: patch here when it breaks.
class YoutubeSource extends MusicSource {
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  TrackSource get kind => TrackSource.youtube;

  @override
  String get name => 'YouTube';

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final res = await _yt.search.search(query);
    final out = <Track>[];
    for (final v in res) {
      if (out.length >= limit) break;
      final d = v.duration;
      if (d != null && d > const Duration(minutes: 25)) continue; // skip mixes / long videos
      out.add(Track(
        id: 'yt:${v.id.value}',
        title: v.title,
        artist: v.author,
        album: 'YouTube',
        source: TrackSource.youtube,
        duration: d,
        artUrl: v.thumbnails.highResUrl,
        extra: v.id.value,
      ));
    }
    return out;
  }

  @override
  Future<ResolvedStream?> resolve(Track t, {required bool lowQuality}) async {
    final id = t.extra ?? t.id.replaceFirst('yt:', '');
    final manifest = await _yt.videos.streamsClient.getManifest(id);
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
    final pick = lowQuality ? pool.first : pool.last;
    return ResolvedStream(pick.url);
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
