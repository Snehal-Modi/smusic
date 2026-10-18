import '../models/track.dart';
import '../state/taste_state.dart';
import 'sources/music_source.dart';

/// A personalised mix shown on Home, e.g. "Arijit Singh mix".
class Mix {
  final String title;
  final String subtitle;
  final List<Track> tracks;
  const Mix({required this.title, required this.subtitle, required this.tracks});
}

/// "More like this": the engine behind Home mixes and the auto-filled queue.
class RecoService {
  RecoService._();

  /// Songs similar to [seed], without the seed itself or anything in [exclude].
  static Future<List<Track>> similarTo(Track seed, {Iterable<Track> exclude = const [], String? language}) async {
    final skip = <String>{seed.id, ...exclude.map((t) => t.id)};
    final lang = seed.lang ?? language ?? 'hindi';
    var artist = TasteState.artistsOf(seed).firstOrNull;

    // Songs from YouTube / Audius carry a channel name, not a real artist.
    // Find the song on Saavn first and take its artist from there.
    if (seed.source != TrackSource.saavn && seed.source != TrackSource.download) {
      try {
        final hits = await Sources.saavn.search(seed.title, limit: 3).timeout(const Duration(seconds: 12));
        if (hits.isNotEmpty) artist = TasteState.artistsOf(hits.first).firstOrNull ?? artist;
      } catch (_) {}
    }
    if (artist == null) return const [];

    final songs = await Sources.saavn.artistRadio(artist, language: lang, count: 20);
    final seen = <String>{};
    return songs.where((t) => !skip.contains(t.id) && seen.add(t.id)).toList();
  }

  /// A mix built around one artist.
  static Future<Mix?> artistMix(String artist, {String language = 'hindi'}) async {
    final songs = await Sources.saavn.artistRadio(artist, language: language, count: 25);
    if (songs.length < 4) return null;
    final seen = <String>{};
    final unique = songs.where((t) => seen.add(t.id)).toList();
    return Mix(title: '$artist mix', subtitle: 'Made for you', tracks: unique);
  }
}
