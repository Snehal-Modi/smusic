import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'sources/music_source.dart';
import 'storage.dart';

/// Saves online songs to app storage for offline play.
class DownloadService extends ChangeNotifier {
  final Store _store;
  DownloadService(this._store) {
    downloads = _store.getJsonList('downloads').map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  late List<Track> downloads;
  final Map<String, double> progress = {};
  final Map<String, String> errors = {};
  Directory? _dir;

  Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    _dir = Directory('${base.path}/downloads');
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
    return _dir!;
  }

  String _dlId(Track t) => 'dl:${t.id}';

  bool isDownloaded(Track t) => downloads.any((d) => d.id == _dlId(t) || d.id == t.id);
  bool isDownloading(Track t) => progress.containsKey(t.id);

  /// The offline copy of an online track, if any (and its file still exists).
  Track? localCopy(Track t) {
    for (final d in downloads) {
      if (d.id == _dlId(t)) {
        final p = d.path;
        if (p != null && File(p).existsSync()) return d;
        return null;
      }
    }
    return null;
  }

  Future<bool> download(Track t) async {
    if (t.isLocal || t.isLive || isDownloaded(t) || isDownloading(t)) return false;
    progress[t.id] = 0;
    errors.remove(t.id);
    notifyListeners();
    http.Client? client;
    File? file;
    try {
      // Always fetch the best quality for the permanent copy.
      final rs = await Sources.resolve(t, quality: StreamQuality.high);
      if (rs == null) throw Exception('no stream');
      final d = await dir();
      final safe = t.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final ext = t.source == TrackSource.audius ? 'mp3' : 'm4a';
      file = File('${d.path}/$safe.$ext');
      client = http.Client();
      final req = http.Request('GET', rs.uri);
      if (rs.headers != null) req.headers.addAll(rs.headers!);
      final resp = await client.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode >= 400) throw Exception('HTTP ${resp.statusCode}');
      final total = resp.contentLength ?? 0;
      int got = 0;
      int lastNotified = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in resp.stream.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0 && got - lastNotified > 64 * 1024) {
            lastNotified = got;
            progress[t.id] = got / total;
            notifyListeners();
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (got < 20000) throw Exception('empty file');
      final copy = Track(
        id: _dlId(t),
        title: t.title,
        artist: t.artist,
        album: t.album,
        source: TrackSource.download,
        duration: t.duration,
        uri: Uri.file(file.path).toString(),
        artUrl: t.artUrl,
        path: file.path,
        dateAdded: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        extra: t.source.name,
      );
      downloads.insert(0, copy);
      _save();
      return true;
    } catch (e) {
      errors[t.id] = 'Download failed';
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
      return false;
    } finally {
      client?.close();
      progress.remove(t.id);
      notifyListeners();
    }
  }

  Future<void> remove(Track d) async {
    downloads.removeWhere((x) => x.id == d.id);
    _save();
    try {
      if (d.path != null) {
        final f = File(d.path!);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  /// Drops entries whose file disappeared (cleared app storage, SD card removed).
  Future<void> prune() async {
    final before = downloads.length;
    final keep = <Track>[];
    for (final d in downloads) {
      final p = d.path;
      if (p != null && await File(p).exists()) keep.add(d);
    }
    if (keep.length != before) {
      downloads = keep;
      _save();
    }
  }

  Future<int> totalBytes() async {
    int n = 0;
    for (final d in downloads) {
      try {
        if (d.path != null) n += await File(d.path!).length();
      } catch (_) {}
    }
    return n;
  }

  void _save() {
    _store.setJsonList('downloads', downloads.map((e) => e.toJson()).toList());
    notifyListeners();
  }
}
