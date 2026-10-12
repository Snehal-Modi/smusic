import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

/// Talks to the Kotlin MediaStore bridge in MainActivity.kt.
class LocalLibrary {
  static const MethodChannel _ch = MethodChannel('smusic/media');

  final Map<int, Uint8List?> _artCache = {};
  final Map<int, Future<Uint8List?>> _inflight = {};
  Directory? _artDir;

  Future<List<Track>> querySongs() async {
    final raw = await _ch.invokeMethod<List<dynamic>>('querySongs');
    if (raw == null) return const [];
    final out = <Track>[];
    for (final e in raw) {
      try {
        out.add(Track.fromMediaStore(e as Map));
      } catch (_) {}
    }
    return out;
  }

  /// Album art bytes for a local track, cached per album.
  Future<Uint8List?> art(Track t, {int size = 320}) {
    final key = t.albumId ?? t.localId ?? -1;
    if (_artCache.containsKey(key)) return Future.value(_artCache[key]);
    final pending = _inflight[key];
    if (pending != null) return pending;
    final f = _fetch(t, size).then((b) {
      _artCache[key] = b;
      _inflight.remove(key);
      return b;
    });
    _inflight[key] = f;
    return f;
  }

  Future<Uint8List?> _fetch(Track t, int size) async {
    try {
      final b = await _ch.invokeMethod<Uint8List>('getArt', {
        'id': t.localId ?? 0,
        'albumId': t.albumId ?? 0,
        'size': size,
      });
      return b;
    } catch (_) {
      return null;
    }
  }

  /// Writes the art to a cache file so the notification / lock screen can show it.
  Future<Uri?> artFileUri(Track t) async {
    final bytes = await art(t, size: 512);
    if (bytes == null) return null;
    try {
      _artDir ??= Directory('${(await getTemporaryDirectory()).path}/art');
      if (!await _artDir!.exists()) await _artDir!.create(recursive: true);
      final f = File('${_artDir!.path}/${t.albumId ?? t.localId}.jpg');
      if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
      return Uri.file(f.path);
    } catch (_) {
      return null;
    }
  }

  void clearArtCache() => _artCache.clear();
}
