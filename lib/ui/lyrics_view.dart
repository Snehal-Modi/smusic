import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/lyrics_service.dart';

/// Synced lyrics that scroll with the song. Tap a line to jump there.
class LyricsView extends StatefulWidget {
  final Track track;
  final bool compact;
  const LyricsView({super.key, required this.track, this.compact = false});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  int _lastIndex = -2;
  Future<Lyrics?>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<LyricsService>().fetch(widget.track);
  }

  @override
  void didUpdateWidget(covariant LyricsView old) {
    super.didUpdateWidget(old);
    if (old.track.id != widget.track.id) {
      _future = context.read<LyricsService>().fetch(widget.track);
      _lastIndex = -2;
      _keys.clear();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(int i) {
    if (i == _lastIndex) return;
    _lastIndex = i;
    final k = _keys[i];
    final ctx = k?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, alignment: 0.38, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final accent = Theme.of(context).colorScheme.primary;
    return FutureBuilder<Lyrics?>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final l = s.data;
        if (l == null || l.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lyrics_outlined, size: 40, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  Text('No lyrics found for this song', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  const SizedBox(height: 4),
                  Text('Lyrics come from LRCLIB and need internet.', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                ],
              ),
            ),
          );
        }
        if (!l.hasSynced) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
            child: Text(l.plain ?? '',
                style: TextStyle(fontSize: widget.compact ? 17 : 21, height: 1.6, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.85))),
          );
        }
        return StreamBuilder<Duration>(
          stream: handler.player.positionStream,
          builder: (c, ps) {
            final pos = ps.data ?? Duration.zero;
            final idx = l.indexAt(pos + const Duration(milliseconds: 300));
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(idx));
            return ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.symmetric(vertical: widget.compact ? 40 : 160, horizontal: 24),
              itemCount: l.synced.length,
              itemBuilder: (c, i) {
                final line = l.synced[i];
                final active = i == idx;
                final past = i < idx;
                final key = _keys.putIfAbsent(i, () => GlobalKey());
                return GestureDetector(
                  key: key,
                  onTap: () => handler.seek(line.time),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: widget.compact ? (active ? 20 : 17) : (active ? 26 : 21),
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : past ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.55),
                        shadows: active ? [Shadow(color: accent.withOpacity(0.6), blurRadius: 18)] : null,
                      ),
                      child: Text(line.text.isEmpty ? '...' : line.text),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
