import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/local_library.dart';

/// Best artwork provider for a track, or null when there is none.
Future<ImageProvider?> artProviderFor(Track t, LocalLibrary lib) async {
  if (t.source == TrackSource.local) {
    final b = await lib.art(t, size: 512);
    return b == null ? null : MemoryImage(b);
  }
  if (t.artUrl != null && t.artUrl!.isNotEmpty) return CachedNetworkImageProvider(t.artUrl!);
  return null;
}

/// Follows the playing track and extracts a dominant "mood" colour from its art,
/// like Spotify's Now Playing background.
class MoodState extends ChangeNotifier {
  final SmusicAudioHandler handler;
  final LocalLibrary lib;
  final Map<String, Color?> _cache = {};

  Color? color;
  ImageProvider? art;
  String? _forId;

  MoodState(this.handler, this.lib) {
    handler.current.addListener(_onTrack);
    _onTrack();
  }

  Future<void> _onTrack() async {
    final t = handler.current.value;
    if (t == null) {
      color = null;
      art = null;
      _forId = null;
      notifyListeners();
      return;
    }
    if (t.id == _forId) return;
    _forId = t.id;
    ImageProvider? p;
    try {
      p = await artProviderFor(t, lib);
    } catch (_) {
      p = null;
    }
    if (_forId != t.id) return;
    art = p;
    if (p == null) {
      color = null;
      notifyListeners();
      return;
    }
    if (_cache.containsKey(t.id)) {
      color = _cache[t.id];
      notifyListeners();
      return;
    }
    notifyListeners();
    try {
      final pal = await PaletteGenerator.fromImageProvider(p, maximumColorCount: 12, size: const Size(120, 120))
          .timeout(const Duration(seconds: 6));
      Color? c = pal.vibrantColor?.color ?? pal.lightVibrantColor?.color ?? pal.dominantColor?.color;
      if (c != null) {
        final hsl = HSLColor.fromColor(c);
        c = hsl.withSaturation((hsl.saturation * 1.1).clamp(0.35, 1.0).toDouble()).withLightness(hsl.lightness.clamp(0.3, 0.6).toDouble()).toColor();
      }
      _cache[t.id] = c;
      if (_forId == t.id) {
        color = c;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    handler.current.removeListener(_onTrack);
    super.dispose();
  }
}
