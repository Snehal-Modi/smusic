import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/sources/music_source.dart';
import '../services/storage.dart';

/// Languages JioSaavn can filter by, in the order shown to the listener.
const List<String> kLanguages = [
  'hindi',
  'english',
  'punjabi',
  'gujarati',
  'marathi',
  'tamil',
  'telugu',
  'kannada',
  'malayalam',
  'bengali',
  'bhojpuri',
  'haryanvi',
  'rajasthani',
  'urdu',
];

/// User preferences. Everything persists immediately.
class SettingsState extends ChangeNotifier {
  final Store _store;
  SettingsState(this._store) {
    online = _store.getBool('online') ?? false;
    final a = _store.getInt('accent');
    accent = a == null ? kAccentPresets.first : Color(a);
    blur = _store.getDouble('blur') ?? 18;
    glassOpacity = _store.getDouble('glassOpacity') ?? 0.10;
    final q = _store.getString('quality');
    if (q != null) {
      quality = streamQualityFrom(q);
    } else {
      // Older builds stored a bool "lowQuality".
      quality = (_store.getBool('lowQuality') ?? false) ? StreamQuality.low : StreamQuality.high;
    }
    bigBuffer = _store.getBool('bigBuffer') ?? false;
    cacheStreams = _store.getBool('cacheStreams') ?? true;
    moodColors = _store.getBool('moodColors') ?? true;
    lyricsOpen = _store.getBool('lyricsOpen') ?? false;
    resumeOnStart = _store.getBool('resumeOnStart') ?? true;
    searchHistory = _store.getJsonList('searchHistory').map((e) => e.toString()).toList();
    final langs = _store.getJsonList('languages').map((e) => e.toString()).toList();
    languages = langs.isEmpty ? ['hindi', 'english'] : langs;
    languagesChosen = _store.getBool('languagesChosen') ?? false;
    autoplay = _store.getBool('autoplay') ?? true;
  }

  /// Music languages picked by the listener, in order of preference.
  late List<String> languages;

  /// False until the listener has picked languages once (Home asks on first run).
  late bool languagesChosen;

  /// Keep the queue filled with similar songs when it runs low.
  late bool autoplay;

  /// false = Local (songs on this phone), true = Online.
  late bool online;
  late Color accent;
  late double blur;
  late double glassOpacity;
  late StreamQuality quality;
  late bool bigBuffer;
  late bool cacheStreams;
  late bool moodColors;
  late bool lyricsOpen;
  late bool resumeOnStart;
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

  void setQuality(StreamQuality q) {
    quality = q;
    _store.setString('quality', q.name);
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

  void setResumeOnStart(bool v) {
    resumeOnStart = v;
    _store.setBool('resumeOnStart', v);
    notifyListeners();
  }

  void setLanguages(List<String> v) {
    languages = v.isEmpty ? ['hindi'] : List.of(v);
    languagesChosen = true;
    _store.setJsonList('languages', languages);
    _store.setBool('languagesChosen', true);
    notifyListeners();
  }

  void setAutoplay(bool v) {
    autoplay = v;
    _store.setBool('autoplay', v);
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
