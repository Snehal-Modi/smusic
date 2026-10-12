import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../services/sources/music_source.dart';

/// Trending rows for the Online home page. Each source loads independently.
class OnlineState extends ChangeNotifier {
  List<Track> saavnTrending = const [];
  List<Track> audiusTrending = const [];
  List<Track> radioTop = const [];
  List<Track> youtubeNew = const [];
  bool loading = false;
  bool loaded = false;
  DateTime? _at;

  Future<void> load({bool force = false}) async {
    if (loading) return;
    final stale = _at == null || DateTime.now().difference(_at!) > const Duration(minutes: 30);
    if (loaded && !force && !stale) return;
    loading = true;
    notifyListeners();
    await Future.wait([
      Sources.saavn.trending().then((v) {
        if (v.isNotEmpty) saavnTrending = v;
        notifyListeners();
      }).catchError((_) {}),
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
    ]);
    loading = false;
    loaded = true;
    _at = DateTime.now();
    notifyListeners();
  }

  bool get isEmpty => saavnTrending.isEmpty && audiusTrending.isEmpty && radioTop.isEmpty && youtubeNew.isEmpty;
}
