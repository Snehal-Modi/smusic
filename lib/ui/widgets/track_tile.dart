import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/track.dart';
import '../../services/audio_handler.dart';
import '../../services/download_service.dart';
import '../../state/collections_state.dart';
import '../../state/library_state.dart';
import '../collection_page.dart';
import 'art.dart';
import 'sheets.dart';

IconData sourceIcon(TrackSource s) {
  switch (s) {
    case TrackSource.local:
      return Icons.phone_android_rounded;
    case TrackSource.download:
      return Icons.download_done_rounded;
    case TrackSource.youtube:
      return Icons.play_circle_outline_rounded;
    case TrackSource.saavn:
      return Icons.graphic_eq_rounded;
    case TrackSource.audius:
      return Icons.waves_rounded;
    case TrackSource.radio:
      return Icons.radio_rounded;
  }
}

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track>? queueContext;
  final int? number;
  final bool showArt;
  final bool showSource;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final Widget? trailing;

  const TrackTile({
    super.key,
    required this.track,
    this.queueContext,
    this.number,
    this.showArt = true,
    this.showSource = false,
    this.onTap,
    this.onRemove,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final accent = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<Track?>(
      valueListenable: handler.current,
      builder: (c, cur, _) {
        final active = cur?.id == track.id;
        return InkWell(
          onTap: onTap ?? () => handler.playTrackIn(track, queueContext ?? [track]),
          onLongPress: () => showTrackMenu(context, track, contextTracks: queueContext, onRemove: onRemove),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                if (number != null && !showArt)
                  SizedBox(
                    width: 32,
                    child: active
                        ? Icon(Icons.graphic_eq_rounded, color: accent, size: 20)
                        : Text('$number', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  ),
                if (showArt) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ArtImage(track: track, size: 50, radius: 10),
                      if (active)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.graphic_eq_rounded, color: accent),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: active ? accent : Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (showSource) ...[
                            Icon(sourceIcon(track.source), size: 12, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              track.isLive ? track.artist : '${track.artist}  -  ${track.album}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (trailing != null)
                  trailing!
                else ...[
                  if (track.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(6)),
                      child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                    )
                  else
                    Text(fmtDuration(track.duration), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  IconButton(
                    icon: Icon(Icons.more_vert_rounded, color: Colors.white.withOpacity(0.7)),
                    onPressed: () => showTrackMenu(context, track, contextTracks: queueContext, onRemove: onRemove),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> showTrackMenu(BuildContext context, Track t, {List<Track>? contextTracks, VoidCallback? onRemove}) async {
  final handler = context.read<SmusicAudioHandler>();
  final col = context.read<CollectionsState>();
  final dl = context.read<DownloadService>();
  final lib = context.read<LibraryState>();
  final liked = col.isLiked(t);
  final canDownload = !t.isLocal && !t.isLive;
  final downloaded = dl.isDownloaded(t);
  final album = t.source == TrackSource.local ? lib.albumOf(t) : null;
  final artist = t.source == TrackSource.local ? lib.artistOf(t) : null;

  await showGlassSheet(
    context,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              ArtImage(track: t, size: 56, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(ctx).textTheme.titleMedium),
                    Text('${t.artist}  -  ${sourceLabel(t.source)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SheetItem(
          icon: Icons.play_arrow_rounded,
          label: 'Play now',
          onTap: () {
            Navigator.pop(ctx);
            handler.playTrackIn(t, contextTracks ?? [t]);
          },
        ),
        SheetItem(
          icon: Icons.playlist_play_rounded,
          label: 'Play next',
          onTap: () {
            Navigator.pop(ctx);
            handler.playNextTrack(t);
            snack(context, 'Playing next');
          },
        ),
        SheetItem(
          icon: Icons.add_to_queue_rounded,
          label: 'Add to queue',
          onTap: () {
            Navigator.pop(ctx);
            handler.enqueue(t);
            snack(context, 'Added to queue');
          },
        ),
        SheetItem(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: liked ? 'Remove from Liked songs' : 'Like',
          color: liked ? Colors.pinkAccent : null,
          onTap: () {
            Navigator.pop(ctx);
            col.toggleLike(t);
          },
        ),
        SheetItem(
          icon: Icons.playlist_add_rounded,
          label: 'Add to playlist',
          onTap: () {
            Navigator.pop(ctx);
            pickPlaylist(context, [t]);
          },
        ),
        if (canDownload)
          SheetItem(
            icon: downloaded ? Icons.download_done_rounded : Icons.download_rounded,
            label: downloaded ? 'Downloaded' : 'Download for offline',
            onTap: downloaded
                ? null
                : () async {
                    Navigator.pop(ctx);
                    snack(context, 'Downloading "${t.title}"');
                    final ok = await dl.download(t);
                    if (context.mounted) snack(context, ok ? 'Saved offline: ${t.title}' : 'Download failed');
                  },
          ),
        if (t.source == TrackSource.download)
          SheetItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete download',
            color: Colors.redAccent,
            onTap: () async {
              Navigator.pop(ctx);
              if (await confirm(context, 'Delete this download?')) dl.remove(t);
            },
          ),
        if (album != null)
          SheetItem(
            icon: Icons.album_rounded,
            label: 'Go to album',
            sub: album.title,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(group: album, kind: CollectionKind.album)));
            },
          ),
        if (artist != null)
          SheetItem(
            icon: Icons.person_rounded,
            label: 'Go to artist',
            sub: artist.title,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(group: artist, kind: CollectionKind.artist)));
            },
          ),
        if (onRemove != null)
          SheetItem(
            icon: Icons.remove_circle_outline_rounded,
            label: 'Remove from this list',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(ctx);
              onRemove();
            },
          ),
      ],
    ),
  );
}
