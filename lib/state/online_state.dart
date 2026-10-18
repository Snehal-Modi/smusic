import 'package:flutter/foundation.dart';

import '../models/podcast.dart';
import '../models/track.dart';
import '../services/podcast_service.dart';
import '../services/reco_service.dart';
import '../services/sources/music_source.dart';
import 'collections_state.dart';
import 'settings_state.dart';
import 'taste_state.dart';

/// Everything on the Online home page. Each part loads independently, so a
/// blocked source never empties the whole page.
class OnlineState extends ChangeNotifier {
  final SettingsState settings;
  final TasteState taste;
  final CollectionsState collections;
  final PodcastService podcasts;

  OnlineState({required this.settings, required this.taste, required this.collections, required this.podcasts});

  /// "Trending in Hindi" per selected language.
  final Map<String, List<Track>> languageRows = {};

  /// "Top 50" chart per selected language.
  final Map<String, List<Track>> languageCharts = {};

  /// Personal mixes built from the taste profile.
  List<Mix> mixes = const [];

  /// "Because you listened to X".
  String? becauseArtist;
  List<Track> becauseTracks = const [];

  List<Podcast> topPodcasts = const [];
  List<Podcast> storyShows = const [];

  List<Track> audiusTrending = const [];
  List<Track> radioTop = const [];
  List<Track> youtubeNew = const [];

  bool loading = false;
  bool loaded = false;
  bool _again = false;
  DateTime? _at;
  String _langKey = '';

  List<String> get _languages => settings.languages.isEmpty ? const ['hindi'] : settings.languages;

  Future<void> load({bool force = false}) async {
    if (loading) {
      _again = true; // languages changed or a refresh was asked for mid-load
      return;
    }
    final key = _languages.join(',');
    final stale = _at == null || DateTime.now().difference(_at!) > const Duration(minutes: 30);
    // An empty result (offline at the time) never counts as fresh.
    if (loaded && !force && !stale && key == _langKey && !isEmpty) return;
    loading = true;
    _langKey = key;
    languageRows.removeWhere((k, _) => !_languages.contains(k));
    languageCharts.removeWhere((k, _) => !_languages.contains(k));
    notifyListeners();

    final langs = _languages.take(4).toList();
    await Future.wait<void>([
      for (final l in langs)
        Sources.saavn.trendingIn(l).then((v) {
          if (v.isNotEmpty) languageRows[l] = v;
          notifyListeners();
        }).catchError((_) {}),
      for (final l in langs.take(2))
        Sources.saavn.chart(l).then((v) {
          if (v.isNotEmpty) languageCharts[l] = v;
          notifyListeners();
        }).catchError((_) {}),
      _loadForYou(langs.first),
      Sources.audius.trending().then((v) {
        if (v.isNotEmpty) audiusTrending = v;
        notifyListeners();
      }).catchError((_) {}),
      Sources.radio.trending().then((v) {
        if (v.isNotEmpty) radioTop = v;
        notifyListeners();
      }).catchError((_) {}),
      Sources.youtube.trending().then((v) {
        if (v.isNotEmpty) youtubeNew = v;
        notifyListeners();
      }).catchError((_) {}),
      podcasts.top(limit: 20).then((v) {
        if (v.isNotEmpty) topPodcasts = v;
        notifyListeners();
      }).catchError((_) {}),
      podcasts.search(_storyTerm(langs.first), limit: 15).then((v) {
        if (v.isNotEmpty) storyShows = v;
        notifyListeners();
      }).catchError((_) {}),
    ]);

    loading = false;
    loaded = true;
    _at = DateTime.now();
    notifyListeners();
    if (_again) {
      _again = false;
      load(force: true);
    }
  }

  static String _storyTerm(String lang) => lang == 'english' ? 'bedtime stories' : '$lang kahani stories';

  /// Mixes and "because you listened" from the taste profile and recent plays.
  Future<void> _loadForYou(String fallbackLang) async {
    try {
      final lang = taste.topLanguages(n: 1).firstOrNull ?? fallbackLang;
      final artists = taste.topArtists(n: 3);

      // The last artist the listener played, if it is not already a mix.
      String? recentArtist;
      for (final t in collections.recent) {
        if (t.source != TrackSource.saavn && t.source != TrackSource.download) continue;
        final a = TasteState.artistsOf(t).firstOrNull;
        if (a != null && !artists.contains(a)) {
          recentArtist = a;
          break;
        }
      }

      final results = await Future.wait<Object?>([
        for (final a in artists) RecoService.artistMix(a, language: lang).catchError((_) => null),
        if (recentArtist != null)
          Sources.saavn.artistRadio(recentArtist, language: lang, count: 20).catchError((_) => <Track>[]),
      ]);

      final built = <Mix>[];
      for (var i = 0; i < artists.length; i++) {
        final m = results[i];
        if (m is Mix) built.add(m);
      }
      mixes = built;
      if (recentArtist != null) {
        final r = results.last;
        becauseArtist = recentArtist;
        becauseTracks = r is List<Track> ? r : const [];
      } else {
        becauseArtist = null;
        becauseTracks = const [];
      }
      notifyListeners();
    } catch (_) {}
  }

  bool get isEmpty =>
      languageRows.isEmpty &&
      audiusTrending.isEmpty &&
      radioTop.isEmpty &&
      youtubeNew.isEmpty &&
      topPodcasts.isEmpty &&
      mixes.isEmpty;
}
