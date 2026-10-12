import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../services/storage.dart';

/// Liked songs, playlists and listening history. Mixed local + online.
class CollectionsState extends ChangeNotifier {
  final Store _store;
  CollectionsState(this._store) {
    liked = _store.getJsonList('liked').map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    playlists = _store.getJsonList('playlists').map((e) => Playlist.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    recent = _store.getJsonList('recent').map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  late List<Track> liked;
  late List<Playlist> playlists;
  late List<Track> recent;

  bool isLiked(Track t) => liked.any((x) => x.id == t.id);

  void toggleLike(Track t) {
    if (isLiked(t)) {
      liked.removeWhere((x) => x.id == t.id);
    } else {
      liked.insert(0, t);
    }
    _store.setJsonList('liked', liked.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Playlist createPlaylist(String name) {
    final p = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'My playlist ${playlists.length + 1}' : name.trim(),
      tracks: [],
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    playlists.insert(0, p);
    _savePlaylists();
    return p;
  }

  Playlist? playlistById(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool addToPlaylist(String id, Track t) {
    final p = playlistById(id);
    if (p == null) return false;
    if (p.tracks.any((x) => x.id == t.id)) return false;
    p.tracks.add(t);
    _savePlaylists();
    return true;
  }

  void addAllToPlaylist(String id, List<Track> tracks) {
    final p = playlistById(id);
    if (p == null) return;
    for (final t in tracks) {
      if (!p.tracks.any((x) => x.id == t.id)) p.tracks.add(t);
    }
    _savePlaylists();
  }

  void removeFromPlaylist(String id, Track t) {
    final p = playlistById(id);
    if (p == null) return;
    p.tracks.removeWhere((x) => x.id == t.id);
    _savePlaylists();
  }

  void moveInPlaylist(String id, int from, int to) {
    final p = playlistById(id);
    if (p == null) return;
    if (from < 0 || from >= p.tracks.length) return;
    final t = p.tracks.removeAt(from);
    if (to > from) to -= 1;
    p.tracks.insert(to.clamp(0, p.tracks.length).toInt(), t);
    _savePlaylists();
  }

  void renamePlaylist(String id, String name) {
    final p = playlistById(id);
    if (p == null || name.trim().isEmpty) return;
    p.name = name.trim();
    _savePlaylists();
  }

  void deletePlaylist(String id) {
    playlists.removeWhere((p) => p.id == id);
    _savePlaylists();
  }

  void _savePlaylists() {
    _store.setJsonList('playlists', playlists.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  void pushRecent(Track t) {
    if (t.isLive && recent.isNotEmpty && recent.first.id == t.id) return;
    recent.removeWhere((x) => x.id == t.id);
    recent.insert(0, t);
    if (recent.length > 60) recent = recent.sublist(0, 60);
    _store.setJsonList('recent', recent.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  void clearRecent() {
    recent = [];
    _store.setJsonList('recent', []);
    notifyListeners();
  }
}
