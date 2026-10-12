import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import 'widgets/art.dart';
import 'widgets/sheets.dart';

Future<void> showQueueSheet(BuildContext context) => showGlassSheet(context, builder: (_) => const QueueSheet(), maxHeightFraction: 0.9);

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final accent = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<List<Track>>(
      valueListenable: handler.queueTracks,
      builder: (c, q, _) => ValueListenableBuilder<int>(
        valueListenable: handler.index,
        builder: (c, idx, _) {
          final total = q.fold<Duration>(Duration.zero, (a, t) => a + (t.duration ?? Duration.zero));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Queue', style: Theme.of(context).textTheme.titleLarge),
                          Text('${plural(q.length, 'song')}  -  ${fmtLong(total)}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: handler.shuffle,
                      builder: (c, s, _) => IconButton(
                        icon: Icon(Icons.shuffle_rounded, color: s ? accent : Colors.white70),
                        onPressed: handler.toggleShuffle,
                        tooltip: 'Shuffle',
                      ),
                    ),
                    ValueListenableBuilder<RepeatMode>(
                      valueListenable: handler.repeat,
                      builder: (c, r, _) => IconButton(
                        icon: Icon(r == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                            color: r == RepeatMode.off ? Colors.white70 : accent),
                        onPressed: handler.cycleRepeat,
                        tooltip: 'Repeat',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
                      tooltip: 'Clear queue',
                      onPressed: q.isEmpty
                          ? null
                          : () async {
                              if (await confirm(context, 'Clear the queue?', yes: 'Clear')) {
                                handler.clearQueue();
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: q.isEmpty
                    ? const Padding(padding: EdgeInsets.all(40), child: Text('Queue is empty'))
                    : ReorderableListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
                        itemCount: q.length,
                        onReorder: handler.move,
                        proxyDecorator: (child, i, anim) => Material(color: Colors.transparent, child: child),
                        itemBuilder: (c, i) {
                          final t = q[i];
                          final active = i == idx;
                          return ListTile(
                            key: ValueKey('q-${t.id}-$i'),
                            dense: true,
                            leading: Stack(
                              alignment: Alignment.center,
                              children: [
                                ArtImage(track: t, size: 44, radius: 10),
                                if (active) Icon(Icons.graphic_eq_rounded, color: accent),
                              ],
                            ),
                            title: Text(t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600, color: active ? accent : Colors.white)),
                            subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => handler.skipToQueueItem(i),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withOpacity(0.6)),
                                  onPressed: () => handler.removeAt(i),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: Icon(Icons.drag_handle_rounded, color: Colors.white.withOpacity(0.5)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
