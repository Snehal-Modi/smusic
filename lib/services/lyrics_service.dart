import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/track.dart';

class LyricLine {
  final Duration time;
  final String text;
  const LyricLine(this.time, this.text);
}

class Lyrics {
  final List<LyricLine> synced;
  final String? plain;
  const Lyrics({required this.synced, this.plain});
  bool get hasSynced => synced.isNotEmpty;
  bool get isEmpty => synced.isEmpty && (plain == null || plain!.trim().isEmpty);

  /// Index of the line that should be highlighted at [pos].
  int indexAt(Duration pos) {
    int i = -1;
    for (int k = 0; k < synced.length; k++) {
      if (synced[k].time <= pos) {
        i = k;
      } else {
        break;
      }
    }
    return i;
  }
}

/// Synced lyrics from LRCLIB (free, no key).
class LyricsService {
  static const _ua = {'User-Agent': 'smusic/1.0 (open source music player)'};
  final Map<String, Lyrics?> _cache = {};

  Future<Lyrics?> fetch(Track t) async {
    if (t.isLive) return null;
    if (_cache.containsKey(t.id)) return _cache[t.id];
    Lyrics? result;
    try {
      result = await _lookup(t);
    } catch (_) {
      result = null;
    }
    _cache[t.id] = result;
    return result;
  }

  Future<Lyrics?> _lookup(Track t) async {
    var title = _cleanTitle(t.title);
    var artist = t.artist;
    // YouTube uploads are often "Artist - Song".
    if (t.source == TrackSource.youtube && title.contains(' - ')) {
      final parts = title.split(' - ');
      artist = parts.first.trim();
      title = parts.sublist(1).join(' - ').trim();
    }
    artist = artist.split(',').first.split('&').first.split(' feat').first.trim();

    final q = <String, String>{
      'track_name': title,
      'artist_name': artist,
    };
    if (t.duration != null && t.source != TrackSource.youtube) {
      q['duration'] = t.duration!.inSeconds.toString();
    }
    if (t.album.isNotEmpty && t.source == TrackSource.local) q['album_name'] = t.album;

    var r = await http
        .get(Uri.https('lrclib.net', '/api/get', q), headers: _ua)
        .timeout(const Duration(seconds: 12));
    Map<String, dynamic>? hit;
    if (r.statusCode == 200) {
      hit = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    } else {
      r = await http
          .get(Uri.https('lrclib.net', '/api/search', {'track_name': title, 'artist_name': artist}), headers: _ua)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body);
        if (list is List && list.isNotEmpty) {
          hit = Map<String, dynamic>.from(list.firstWhere(
            (e) => (e['syncedLyrics'] ?? '').toString().isNotEmpty,
            orElse: () => list.first,
          ) as Map);
        }
      }
      if (hit == null) {
        r = await http
            .get(Uri.https('lrclib.net', '/api/search', {'q': '$artist $title'}), headers: _ua)
            .timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) {
          final list = jsonDecode(r.body);
          if (list is List && list.isNotEmpty) hit = Map<String, dynamic>.from(list.first as Map);
        }
      }
    }
    if (hit == null) return null;
    final synced = parseLrc((hit['syncedLyrics'] ?? '').toString());
    final plain = (hit['plainLyrics'] ?? '').toString();
    final l = Lyrics(synced: synced, plain: plain.isEmpty ? null : plain);
    return l.isEmpty ? null : l;
  }

  static String _cleanTitle(String s) {
    var t = s;
    t = t.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*(official|video|audio|lyric|lyrics|hd|4k|remaster|visualizer|mv)[^\)\]]*[\)\]]', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*\|.*$'), '');
    t = t.replaceAll(RegExp(r'\s*(official video|official audio|lyric video|full song|full video)\s*', caseSensitive: false), ' ');
    return t.trim();
  }

  static List<LyricLine> parseLrc(String lrc) {
    if (lrc.trim().isEmpty) return const [];
    final re = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');
    final out = <LyricLine>[];
    for (final raw in lrc.split('\n')) {
      final line = raw.trimRight();
      final matches = re.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.substring(matches.last.end).trim();
      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final fracStr = m.group(3) ?? '0';
        final frac = int.parse(fracStr.padRight(3, '0').substring(0, 3));
        out.add(LyricLine(Duration(minutes: min, seconds: sec, milliseconds: frac), text));
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }
}
