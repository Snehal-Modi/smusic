import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../core/glass.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import 'now_playing.dart';
import 'widgets/art.dart';

/// The bar above the navigation: tap or swipe up to open Now Playing,
/// swipe left / right to change song.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final accent = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<Track?>(
      valueListenable: handler.current,
      builder: (c, t, _) {
        if (t == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => openNowPlaying(context),
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -200) openNowPlaying(context);
          },
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -300) handler.skipToNext();
            if (v > 300) handler.skipToPrevious();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: GlassPanel(
              radius: 20,
              tint: const Color(0xFF2A2A44),
              opacity: 0.5,
              blur: 26,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 6, 6),
                    child: Row(
                      children: [
                        Hero(tag: 'now-art', child: ArtImage(track: t, size: 46, radius: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                              ValueListenableBuilder<bool>(
                                valueListenable: handler.resolving,
                                builder: (c, r, _) => Text(
                                  r ? 'Loading...' : t.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: handler.player.playerStateStream,
                          builder: (c, s) {
                            final st = s.data;
                            final playing = st?.playing ?? false;
                            final loading = st?.processingState == ProcessingState.loading ||
                                st?.processingState == ProcessingState.buffering;
                            return Row(
                              children: [
                                if (loading)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                else
                                  IconButton(
                                    iconSize: 30,
                                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                    onPressed: handler.togglePlay,
                                  ),
                                IconButton(
                                  iconSize: 26,
                                  icon: const Icon(Icons.skip_next_rounded),
                                  onPressed: handler.skipToNext,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // thin progress line
                  StreamBuilder<Duration>(
                    stream: handler.player.positionStream,
                    builder: (c, s) {
                      final d = handler.player.duration;
                      final p = s.data ?? Duration.zero;
                      final v = (d == null || d.inMilliseconds == 0 || t.isLive) ? 0.0 : (p.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0).toDouble();
                      return ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                        child: LinearProgressIndicator(
                          value: t.isLive ? null : v,
                          minHeight: 2.5,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          color: accent,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
