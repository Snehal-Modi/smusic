import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/formatters.dart';
import '../models/track.dart';
import '../services/local_library.dart';

/// Songs on the device, grouped into albums / artists / folders.
class LibraryState extends ChangeNotifier {
  final LocalLibrary library;
  LibraryState(this.library);

  List<Track> songs = const [];
  List<TrackGroup> albums = const [];
  List<TrackGroup> artists = const [];
  List<TrackGroup> folders = const [];
  bool loading = false;
  bool loaded = false;
  bool denied = false;

  /// True when the user chose "Don't ask again": only the system settings
  /// page can fix it now.
  bool permanentlyDenied = false;
  bool _askedNotifications = false;

  Future<void> load({bool force = false}) async {
    if (loading) return;
    if (loaded && !force) return;
    loading = true;
    notifyListeners();
    try {
      // Android 13+: READ_MEDIA_AUDIO. Older: READ_EXTERNAL_STORAGE
      // (permission_handler maps `audio` to it automatically).
      var status = await Permission.audio.status;
      if (!status.isGranted) status = await Permission.audio.request();
      if (!status.isGranted) {
        final st = await Permission.storage.request();
        denied = !st.isGranted;
        permanentlyDenied = status.isPermanentlyDenied || st.isPermanentlyDenied;
      } else {
        denied = false;
        permanentlyDenied = false;
      }
      if (!denied) {
        songs = await library.querySongs();
        _group();
      }
      loaded = true;
      _askNotifications();
    } catch (_) {
      // keep what we had
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Android 13+ needs this for the playback notification / lock-screen
  /// controls. Asked once, after the music permission so the prompts don't
  /// stack up on first launch.
  Future<void> _askNotifications() async {
    if (_askedNotifications) return;
    _askedNotifications = true;
    try {
      final s = await Permission.notification.status;
      if (s.isDenied) await Permission.notification.request();
    } catch (_) {}
  }

  void _group() {
    final byAlbum = <String, List<Track>>{};
    final byArtist = <String, List<Track>>{};
    final byFolder = <String, List<Track>>{};
    for (final t in songs) {
      byAlbum.putIfAbsent('${t.album}|${t.albumId ?? ''}', () => []).add(t);
      byArtist.putIfAbsent(t.artist, () => []).add(t);
      byFolder.putIfAbsent(t.folder, () => []).add(t);
    }
    albums = byAlbum.entries.map((e) {
      final tracks = List.of(e.value)..sort((a, b) => (a.trackNo ?? 0).compareTo(b.trackNo ?? 0));
      final artistsIn = tracks.map((t) => t.artist).toSet();
      return TrackGroup(
        key: e.key,
        title: tracks.first.album,
        subtitle: artistsIn.length == 1 ? artistsIn.first : 'Various artists',
        tracks: tracks,
      );
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    artists = byArtist.entries
        .map((e) => TrackGroup(
              key: e.key,
              title: e.key,
              subtitle: plural(e.value.length, 'song'),
              tracks: e.value,
            ))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    folders = byFolder.entries
        .map((e) => TrackGroup(
              key: e.key,
              title: e.value.first.folderName.isEmpty ? 'Storage' : e.value.first.folderName,
              subtitle: '${plural(e.value.length, 'song')}  -  ${e.key}',
              tracks: e.value,
            ))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  List<Track> get recentlyAdded {
    final l = List.of(songs)..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    return l.take(20).toList();
  }

  List<Track> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return const [];
    return songs
        .where((t) =>
            t.title.toLowerCase().contains(s) || t.artist.toLowerCase().contains(s) || t.album.toLowerCase().contains(s))
        .toList();
  }

  TrackGroup? albumOf(Track t) {
    for (final a in albums) {
      if (a.tracks.contains(t)) return a;
    }
    return null;
  }

  TrackGroup? artistOf(Track t) {
    for (final a in artists) {
      if (a.title == t.artist) return a;
    }
    return null;
  }
}
