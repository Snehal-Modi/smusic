import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../services/storage.dart';

/// What the listener likes, learned from what they actually play.
///
/// Every play adds weight to the artists and language of the song, a like adds
/// more, a quick skip takes some away, and older taste fades slowly so the mixes
/// follow the listener's current mood. Stored on the phone only.
class TasteState extends ChangeNotifier {
  final Store _store;

  Map<String, double> artists = {};
  Map<String, double> languages = {};

  TasteState(this._store) {
    final m = _store.getJsonMap('taste');
    if (m != null) {
      artists = _toWeights(m['artists']);
      languages = _toWeights(m['languages']);
    }
  }

  static Map<String, double> _toWeights(dynamic v) {
    final out = <String, double>{};
    if (v is Map) {
      v.forEach((k, w) {
        if (w is num) out[k.toString()] = w.toDouble();
      });
    }
    return out;
  }

  static const _skipNames = {'unknown artist', 'various artists', 'audius artist', ''};

  /// The artists of a song as separate names ("A, B & C" -> A, B, C).
  static List<String> artistsOf(Track t) {
    return t.artist
        .split(RegExp(r',|&|\bfeat\.?\b|\bft\.?\b'))
        .map((s) => s.trim())
        .where((s) => !_skipNames.contains(s.toLowerCase()))
        .toList();
  }

  /// Only songs Saavn knows about teach us something we can act on, because
  /// suggestions are fetched from there. Downloads keep their origin in `extra`.
  static bool _learnable(Track t) {
    if (t.isLive || t.isPodcast) return false;
    return t.source == TrackSource.saavn || (t.source == TrackSource.download && t.extra == TrackSource.saavn.name);
  }

  bool get hasData => artists.isNotEmpty;

  void _bump(Track t, double amount) {
    final names = artistsOf(t).take(2).toList();
    for (final a in names) {
      artists[a] = (artists[a] ?? 0) + amount;
    }
    final l = t.lang;
    if (l != null && l.isNotEmpty) languages[l] = (languages[l] ?? 0) + amount;
  }

  void recordListen(Track t) {
    if (!_learnable(t)) return;
    _fade();
    _bump(t, 1);
    _commit();
  }

  void recordLike(Track t) {
    if (!_learnable(t)) return;
    _bump(t, 3);
    _commit();
  }

  void recordSkip(Track t) {
    if (!_learnable(t)) return;
    _bump(t, -0.6);
    _commit();
  }

  void _fade() {
    artists.updateAll((k, v) => v * 0.985);
    languages.updateAll((k, v) => v * 0.985);
  }

  void _commit() {
    artists.removeWhere((k, v) => v < 0.15);
    languages.removeWhere((k, v) => v < 0.15);
    if (artists.length > 80) {
      final keep = _top(artists, 60);
      artists = {for (final k in keep) k: artists[k]!};
    }
    _store.setJsonMap('taste', {'artists': artists, 'languages': languages});
    notifyListeners();
  }

  static List<String> _top(Map<String, double> m, int n) {
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.take(n).map((x) => x.key).toList();
  }

  List<String> topArtists({int n = 5}) => _top(artists, n);
  List<String> topLanguages({int n = 3}) => _top(languages, n);

  void reset() {
    artists = {};
    languages = {};
    _store.setJsonMap('taste', {'artists': artists, 'languages': languages});
    notifyListeners();
  }
}
