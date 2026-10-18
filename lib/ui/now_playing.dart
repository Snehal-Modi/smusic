import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/glass.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/download_service.dart';
import '../state/collections_state.dart';
import '../state/mood_state.dart';
import '../state/settings_state.dart';
import 'equalizer_sheet.dart';
import 'lyrics_view.dart';
import 'queue_sheet.dart';
import 'widgets/art.dart';
import 'widgets/sheets.dart';
import 'widgets/track_tile.dart';

Future<void> openNowPlaying(BuildContext context) {
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (c, a, s) => const NowPlayingPage(),
    transitionsBuilder: (c, a, s, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  ));
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late bool _lyrics = context.read<SettingsState>().lyricsOpen;

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final mood = context.watch<MoodState>();
    final settings = context.watch<SettingsState>();
    final accent = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<Track?>(
      valueListenable: handler.current,
      builder: (c, t, _) {
        if (t == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.maybePop(context));
          return const SizedBox.shrink();
        }
        return Scaffold(
          body: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 350) Navigator.maybePop(context);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                GlassBackdrop(accent: accent, mood: settings.moodColors ? mood.color : null, art: mood.art),
                SafeArea(
                  child: LayoutBuilder(builder: (c, box) {
                    final wide = box.maxWidth >= 760;
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(child: _MainColumn(track: t, lyricsOpen: false, onToggleLyrics: null, wide: true)),
                          SizedBox(
                            width: box.maxWidth * 0.42,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                              child: GlassPanel(
                                radius: 28,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text('Lyrics', style: Theme.of(context).textTheme.titleLarge)),
                                          IconButton(icon: const Icon(Icons.queue_music_rounded), onPressed: () => showQueueSheet(context)),
                                        ],
                                      ),
                                    ),
                                    Expanded(child: LyricsView(track: t, compact: true)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return _MainColumn(
                      track: t,
                      lyricsOpen: _lyrics,
                      wide: false,
                      onToggleLyrics: () {
                        setState(() => _lyrics = !_lyrics);
                        settings.setLyricsOpen(_lyrics);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MainColumn extends StatelessWidget {
  final Track track;
  final bool lyricsOpen;
  final bool wide;
  final VoidCallback? onToggleLyrics;
  const _MainColumn({required this.track, required this.lyricsOpen, required this.wide, required this.onToggleLyrics});

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final col = context.watch<CollectionsState>();
    final accent = Theme.of(context).colorScheme.primary;
    final liked = col.isLiked(track);

    return Column(
      children: [
        // top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              GlassIconButton(icon: Icons.keyboard_arrow_down_rounded, onPressed: () => Navigator.maybePop(context), iconSize: 28),
              Expanded(
                child: Column(
                  children: [
                    Text('PLAYING FROM', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w700)),
                    Text(sourceLabel(track.source), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
              GlassIconButton(icon: Icons.more_horiz_rounded, onPressed: () => _more(context)),
            ],
          ),
        ),
        // art or lyrics
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: lyricsOpen
                ? Padding(
                    key: const ValueKey('lyrics'),
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: GlassPanel(radius: 28, child: LyricsView(track: track)),
                  )
                : _Artwork(key: const ValueKey('art'), track: track, wide: wide),
          ),
        ),
        // title row
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(height: 3),
                    Text(track.isLive ? track.artist : '${track.artist}${track.album.isNotEmpty ? '  -  ${track.album}' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, color: Colors.white.withOpacity(0.65))),
                  ],
                ),
              ),
              IconButton(
                iconSize: 28,
                icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? Colors.pinkAccent : Colors.white),
                onPressed: () => col.toggleLike(track),
              ),
            ],
          ),
        ),
        // seek bar
        _SeekBar(track: track),
        // controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: handler.shuffle,
                builder: (c, s, _) => IconButton(
                  iconSize: 24,
                  icon: Icon(Icons.shuffle_rounded, color: s ? accent : Colors.white70),
                  onPressed: handler.toggleShuffle,
                ),
              ),
              GlassIconButton(icon: Icons.skip_previous_rounded, onPressed: handler.skipToPrevious, size: 56, iconSize: 32),
              StreamBuilder<PlayerState>(
                stream: handler.player.playerStateStream,
                builder: (c, s) {
                  final st = s.data;
                  final playing = st?.playing ?? false;
                  final loading = st?.processingState == ProcessingState.loading || st?.processingState == ProcessingState.buffering;
                  return GlassIconButton(
                    icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    onPressed: handler.togglePlay,
                    size: 76,
                    iconSize: 40,
                    filled: true,
                    color: loading ? onAccent(accent).withOpacity(0.5) : null,
                  );
                },
              ),
              GlassIconButton(icon: Icons.skip_next_rounded, onPressed: handler.skipToNext, size: 56, iconSize: 32),
              ValueListenableBuilder<RepeatMode>(
                valueListenable: handler.repeat,
                builder: (c, r, _) => IconButton(
                  iconSize: 24,
                  icon: Icon(r == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                      color: r == RepeatMode.off ? Colors.white70 : accent),
                  onPressed: handler.cycleRepeat,
                ),
              ),
            ],
          ),
        ),
        // secondary row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Back 10 seconds',
                icon: const Icon(Icons.replay_10_rounded),
                onPressed: track.isLive ? null : () => handler.seekBy(const Duration(seconds: -10)),
              ),
              IconButton(
                tooltip: 'Forward 10 seconds',
                icon: const Icon(Icons.forward_10_rounded),
                onPressed: track.isLive ? null : () => handler.seekBy(const Duration(seconds: 10)),
              ),
              if (onToggleLyrics != null)
                IconButton(
                  tooltip: 'Lyrics',
                  icon: Icon(Icons.lyrics_outlined, color: lyricsOpen ? accent : Colors.white),
                  onPressed: track.isLive ? null : onToggleLyrics,
                ),
              ValueListenableBuilder<Duration?>(
                valueListenable: handler.sleepLeft,
                builder: (c, left, _) => IconButton(
                  tooltip: 'Sleep timer',
                  icon: Icon(left == null ? Icons.bedtime_outlined : Icons.bedtime_rounded, color: left == null ? Colors.white : accent),
                  onPressed: () => _sleep(context),
                ),
              ),
              IconButton(tooltip: 'Queue', icon: const Icon(Icons.queue_music_rounded), onPressed: () => showQueueSheet(context)),
            ],
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: handler.lastError,
          builder: (c, e, _) => e == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(e, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ),
        ),
      ],
    );
  }

  Future<void> _sleep(BuildContext context) async {
    final handler = context.read<SmusicAudioHandler>();
    await showGlassSheet(
      context,
      builder: (ctx) => ValueListenableBuilder<Duration?>(
        valueListenable: handler.sleepLeft,
        builder: (c, left, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(left == null ? 'Sleep timer' : 'Stops in ${fmtDuration(left)}', style: Theme.of(ctx).textTheme.titleLarge),
            ),
            for (final m in [10, 15, 30, 45, 60, 90])
              SheetItem(
                icon: Icons.timer_outlined,
                label: '$m minutes',
                onTap: () {
                  handler.setSleep(Duration(minutes: m));
                  Navigator.pop(ctx);
                },
              ),
            ValueListenableBuilder<bool>(
              valueListenable: handler.sleepAtEnd,
              builder: (c, v, _) => SheetItem(
                icon: Icons.stop_circle_outlined,
                label: 'End of this song',
                trailing: v ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary) : null,
                onTap: () {
                  handler.setSleepAtEnd(!v);
                  Navigator.pop(ctx);
                },
              ),
            ),
            if (left != null)
              SheetItem(
                icon: Icons.close_rounded,
                label: 'Turn off timer',
                color: Colors.redAccent,
                onTap: () {
                  handler.setSleep(null);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _more(BuildContext context) async {
    final handler = context.read<SmusicAudioHandler>();
    final dl = context.read<DownloadService>();
    await showGlassSheet(
      context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        children: [
          StreamBuilder<double>(
            stream: handler.player.speedStream,
            builder: (c, s) {
              final sp = s.data ?? 1.0;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.speed_rounded, color: Colors.white70),
                        const SizedBox(width: 14),
                        Text('Speed  ${sp.toStringAsFixed(2)}x', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Slider(
                    value: sp,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: track.isLive ? null : (v) => handler.setSpeed(v),
                  ),
                ],
              );
            },
          ),
          SheetItem(
            icon: Icons.equalizer_rounded,
            label: 'Equalizer and bass',
            onTap: () {
              Navigator.pop(ctx);
              showEqualizerSheet(context);
            },
          ),
          SheetItem(
            icon: Icons.playlist_add_rounded,
            label: 'Add to playlist',
            onTap: () {
              Navigator.pop(ctx);
              pickPlaylist(context, [track]);
            },
          ),
          if (!track.isLocal && !track.isLive)
            SheetItem(
              icon: dl.isDownloaded(track) ? Icons.download_done_rounded : Icons.download_rounded,
              label: dl.isDownloaded(track) ? 'Downloaded' : 'Download for offline',
              onTap: dl.isDownloaded(track)
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      snack(context, 'Downloading "${track.title}"');
                      final ok = await dl.download(track);
                      if (context.mounted) snack(context, ok ? 'Saved offline' : 'Download failed');
                    },
            ),
          SheetItem(
            icon: Icons.info_outline_rounded,
            label: 'Song details',
            onTap: () {
              Navigator.pop(ctx);
              showTrackMenu(context, track);
            },
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final Track track;
  final bool wide;
  const _Artwork({super.key, required this.track, required this.wide});

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    return LayoutBuilder(builder: (c, box) {
      final size = math.max(120.0, math.min(box.maxWidth - 56, box.maxHeight - 24));
      return GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -300) handler.skipToNext();
          if (v > 300) handler.skipToPrevious();
        },
        onDoubleTap: handler.togglePlay,
        child: Center(
          child: Hero(
            tag: 'now-art',
            child: StreamBuilder<bool>(
              stream: handler.player.playingStream,
              builder: (c, s) {
                final playing = s.data ?? false;
                return AnimatedScale(
                  scale: playing ? 1 : 0.92,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 50, offset: const Offset(0, 24)),
                      ],
                    ),
                    child: ArtImage(track: track, size: size, radius: 28),
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
  }
}

class _SeekBar extends StatefulWidget {
  final Track track;
  const _SeekBar({required this.track});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final accent = Theme.of(context).colorScheme.primary;
    if (widget.track.isLive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('LIVE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, color: Colors.white.withOpacity(0.8))),
            const Spacer(),
            StreamBuilder<ProcessingState>(
              stream: handler.player.processingStateStream,
              builder: (c, s) => Text(
                s.data == ProcessingState.buffering || s.data == ProcessingState.loading ? 'Buffering...' : 'Streaming',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    return StreamBuilder<Duration>(
      stream: handler.player.positionStream,
      builder: (c, ps) {
        final dur = handler.player.duration ?? widget.track.duration ?? Duration.zero;
        final pos = ps.data ?? Duration.zero;
        final buf = handler.player.bufferedPosition;
        final max = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity).toDouble();
        final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max).toDouble();
        final bufV = buf.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Column(
            children: [
              SizedBox(
                height: 34,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: bufV / max,
                          minHeight: 4,
                          backgroundColor: Colors.transparent,
                          color: Colors.white.withOpacity(0.22),
                        ),
                      ),
                    ),
                    Slider(
                      value: value,
                      max: max,
                      activeColor: accent,
                      inactiveColor: Colors.white.withOpacity(0.12),
                      onChanged: (v) => setState(() => _drag = v),
                      onChangeEnd: (v) {
                        handler.seek(Duration(milliseconds: v.round()));
                        setState(() => _drag = null);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Text(fmtDuration(Duration(milliseconds: value.round())), style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    StreamBuilder<ProcessingState>(
                      stream: handler.player.processingStateStream,
                      builder: (c, s) => s.data == ProcessingState.buffering || s.data == ProcessingState.loading
                          ? Text('buffering', style: TextStyle(fontSize: 11, color: accent))
                          : const SizedBox.shrink(),
                    ),
                    const Spacer(),
                    Text('-${fmtDuration(dur - Duration(milliseconds: value.round()))}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

