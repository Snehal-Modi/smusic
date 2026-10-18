import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/local_library.dart';

/// Album art for any track: local bytes via MediaStore, network for online.
class ArtImage extends StatelessWidget {
  final Track? track;
  final double size;
  final double radius;
  final bool circle;
  final BoxFit fit;

  const ArtImage({
    super.key,
    required this.track,
    this.size = 56,
    this.radius = 12,
    this.circle = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final t = track;
    Widget child;
    if (t == null) {
      child = _Placeholder(size: size, icon: Icons.music_note_rounded);
    } else if (t.source == TrackSource.local) {
      final lib = context.read<LocalLibrary>();
      child = FutureBuilder<Uint8List?>(
        future: lib.art(t, size: size > 200 ? 640 : 320),
        builder: (c, s) {
          final b = s.data;
          if (b == null) return _Placeholder(size: size, icon: Icons.music_note_rounded, loading: !s.hasData && s.connectionState != ConnectionState.done);
          return Image.memory(b, width: size, height: size, fit: fit, gaplessPlayback: true, filterQuality: FilterQuality.medium);
        },
      );
    } else if (t.artUrl != null && t.artUrl!.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: t.artUrl!,
        width: size,
        height: size,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (c, u) => _Placeholder(size: size, icon: _iconFor(t), loading: true),
        errorWidget: (c, u, e) => _Placeholder(size: size, icon: _iconFor(t)),
      );
    } else {
      child = _Placeholder(size: size, icon: _iconFor(t));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(circle ? size / 2 : radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  static IconData _iconFor(Track t) {
    switch (t.source) {
      case TrackSource.radio:
        return Icons.radio_rounded;
      case TrackSource.youtube:
        return Icons.play_circle_outline_rounded;
      case TrackSource.podcast:
        return Icons.podcasts_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  final IconData icon;
  final bool loading;
  const _Placeholder({required this.size, required this.icon, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.55), const Color(0xFF1A1A2A)],
        ),
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: size * 0.25,
                height: size * 0.25,
                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              )
            : Icon(icon, size: size * 0.42, color: Colors.white.withOpacity(0.8)),
      ),
    );
  }
}
