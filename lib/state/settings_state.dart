import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/storage.dart';

/// User preferences. Everything persists immediately.
class SettingsState extends ChangeNotifier {
  final Store _store;
  SettingsState(this._store) {
    online = _store.getBool('online') ?? false;
    final a = _store.getInt('accent');
    accent = a == null ? kAccentPresets.first : Color(a);
    blur = _store.getDouble('blur') ?? 18;
    glassOpacity = _store.getDouble('glassOpacity') ?? 0.10;
    lowQuality = _store.getBool('lowQuality') ?? false;
    bigBuffer = _store.getBool('bigBuffer') ?? false;
    cacheStreams = _store.getBool('cacheStreams') ?? true;
    moodColors = _store.getBool('moodColors') ?? true;
    lyricsOpen = _store.getBool('lyricsOpen') ?? false;
    searchHistory = _store.getJsonList('searchHistory').map((e) => e.toString()).toList();
  }

  /// false = Local (songs on this phone), true = Online.
  late bool online;
  late Color accent;
  late double blur;
  late double glassOpacity;
  late bool lowQuality;
  late bool bigBuffer;
  late bool cacheStreams;
  late bool moodColors;
  late bool lyricsOpen;
  late List<String> searchHistory;

  void setOnline(bool v) {
    if (online == v) return;
    online = v;
    _store.setBool('online', v);
    notifyListeners();
  }

  void setAccent(Color c) {
    accent = c;
    _store.setInt('accent', c.value);
    notifyListeners();
  }

  void setBlur(double v) {
    blur = v;
    _store.setDouble('blur', v);
    notifyListeners();
  }

  void setGlassOpacity(double v) {
    glassOpacity = v;
    _store.setDouble('glassOpacity', v);
    notifyListeners();
  }

  void setLowQuality(bool v) {
    lowQuality = v;
    _store.setBool('lowQuality', v);
    notifyListeners();
  }

  void setBigBuffer(bool v) {
    bigBuffer = v;
    _store.setBool('bigBuffer', v);
    notifyListeners();
  }

  void setCacheStreams(bool v) {
    cacheStreams = v;
    _store.setBool('cacheStreams', v);
    notifyListeners();
  }

  void setMoodColors(bool v) {
    moodColors = v;
    _store.setBool('moodColors', v);
    notifyListeners();
  }

  void setLyricsOpen(bool v) {
    lyricsOpen = v;
    _store.setBool('lyricsOpen', v);
    notifyListeners();
  }

  void addSearch(String q) {
    final s = q.trim();
    if (s.isEmpty) return;
    searchHistory.remove(s);
    searchHistory.insert(0, s);
    if (searchHistory.length > 15) searchHistory = searchHistory.sublist(0, 15);
    _store.setJsonList('searchHistory', searchHistory);
    notifyListeners();
  }

  void clearSearchHistory() {
    searchHistory = [];
    _store.setJsonList('searchHistory', []);
    notifyListeners();
  }
}
