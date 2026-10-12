import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/glass.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/download_service.dart';
import '../state/collections_state.dart';
import '../state/mood_state.dart';
import 'widgets/art.dart';
import 'widgets/header.dart';
import 'widgets/sheets.dart';
import 'widgets/track_tile.dart';

enum CollectionKind { album, artist, folder, playlist, liked, downloads, recent }

/// One page for every "list of songs": album, artist, folder, playlist, liked, downloads, history.
class CollectionPage extends StatelessWidget {
  final CollectionKind kind;
  final TrackGroup? group;
  final String? playlistId;
  const CollectionPage({super.key, required this.kind, this.group, this.playlistId});

  @override
  Widget build(BuildContext context) {
    final col = context.watch<CollectionsState>();
    final dl = context.watch<DownloadService>();
    final handler = context.read<SmusicAudioHandler>();
    final mood = context.watch<MoodState>();
    final accent = Theme.of(context).colorScheme.primary;

    Playlist? playlist;
    List<Track> tracks;
    String title;
    String subtitle;
    switch (kind) {
      case CollectionKind.playlist:
        playlist = playlistId == null ? null : col.playlistById(playlistId!);
        tracks = playlist?.tracks ?? const [];
        title = playlist?.name ?? 'Playlist';
        subtitle = 'Playlist';
        break;
      case CollectionKind.liked:
        tracks = col.liked;
        title = 'Liked songs';
        subtitle = 'Your favourites';
        break;
      case CollectionKind.downloads:
        tracks = dl.downloads;
        title = 'Downloads';
        subtitle = 'Available offline';
        break;
      case CollectionKind.recent:
        tracks = col.recent;
        title = 'Recently played';
        subtitle = 'History';
        break;
      default:
        tracks = group?.tracks ?? const [];
        title = group?.title ?? '';
        subtitle = kind == CollectionKind.album
            ? (group?.subtitle ?? '')
            : kind == CollectionKind.artist
                ? 'Artist'
                : 'Folder';
    }
    final total = tracks.fold<Duration>(Duration.zero, (a, t) => a + (t.duration ?? Duration.zero));
    final cover = tracks.isEmpty ? null : tracks.first;
    final circle = kind == CollectionKind.artist;
    final numbered = kind == CollectionKind.album;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GlassBackdrop(accent: accent, mood: mood.color)),
          LayoutBuilder(builder: (c, box) {
            final wide = box.maxWidth >= 760;
            final header = _Header(
              title: title,
              subtitle: subtitle,
              meta: tracks.isEmpty ? 'No songs yet' : '${plural(tracks.length, 'song')}  -  ${fmtLong(total)}',
              cover: cover,
              circle: circle,
              wide: wide,
              onPlay: tracks.isEmpty ? null : () => handler.playAll(tracks),
              onShuffle: tracks.isEmpty ? null : () => handler.playAll(tracks, shuffleMode: true),
              onMore: () => _more(context, tracks, playlist),
            );
            final list = SliverPadding(
              padding: const EdgeInsets.only(bottom: 110, top: 6),
              sliver: tracks.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyNote(
                        icon: Icons.music_off_rounded,
                        title: kind == CollectionKind.playlist
                            ? 'This playlist is empty'
                            : kind == CollectionKind.liked
                                ? 'No liked songs yet'
                                : kind == CollectionKind.downloads
                                    ? 'Nothing downloaded yet'
                                    : 'Nothing here yet',
                        body: kind == CollectionKind.playlist
                            ? 'Long-press any song and choose Add to playlist.'
                            : kind == CollectionKind.downloads
                                ? 'Open any online song menu and choose Download for offline.'
                                : null,
                      ),
                    )
                  : SliverList.builder(
                      itemCount: tracks.length,
                      itemBuilder: (c, i) => TrackTile(
                        track: tracks[i],
                        queueContext: tracks,
                        number: numbered ? i + 1 : null,
                        showArt: !numbered,
                        showSource: kind == CollectionKind.playlist || kind == CollectionKind.liked || kind == CollectionKind.recent,
                        onRemove: kind == CollectionKind.playlist && playlist != null
                            ? () => col.removeFromPlaylist(playlist!.id, tracks[i])
                            : kind == CollectionKind.liked
                                ? () => col.toggleLike(tracks[i])
                                : null,
                      ),
                    ),
            );
            if (wide) {
              return SafeArea(
                child: Row(
                  children: [
                    SizedBox(width: 340, child: SingleChildScrollView(child: header)),
                    Expanded(
                      child: CustomScrollView(slivers: [
                        SliverToBoxAdapter(child: _TopBar(title: null)),
                        list,
                      ]),
                    ),
                  ],
                ),
              );
            }
            return SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _TopBar(title: null)),
                  SliverToBoxAdapter(child: header),
                  list,
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _more(BuildContext context, List<Track> tracks, Playlist? pl) async {
    final handler = context.read<SmusicAudioHandler>();
    final col = context.read<CollectionsState>();
    final playlist = pl;
    await showGlassSheet(
      context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        children: [
          SheetItem(
            icon: Icons.add_to_queue_rounded,
            label: 'Add all to queue',
            onTap: tracks.isEmpty
                ? null
                : () {
                    Navigator.pop(ctx);
                    handler.enqueueAll(tracks);
                    snack(context, 'Added ${tracks.length} songs to queue');
                  },
          ),
          SheetItem(
            icon: Icons.playlist_add_rounded,
            label: 'Add all to a playlist',
            onTap: tracks.isEmpty
                ? null
                : () {
                    Navigator.pop(ctx);
                    pickPlaylist(context, tracks);
                  },
          ),
          if (playlist != null) ...[
            SheetItem(
              icon: Icons.drive_file_rename_outline_rounded,
              label: 'Rename playlist',
              onTap: () async {
                Navigator.pop(ctx);
                final n = await askText(context, title: 'Rename playlist', initial: playlist.name);
                if (n != null) col.renamePlaylist(playlist.id, n);
              },
            ),
            SheetItem(
              icon: Icons.delete_outline_rounded,
              label: 'Delete playlist',
              color: Colors.redAccent,
              onTap: () async {
                Navigator.pop(ctx);
                if (await confirm(context, 'Delete "${playlist.name}"?')) {
                  col.deletePlaylist(playlist.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
          if (kind == CollectionKind.recent)
            SheetItem(
              icon: Icons.delete_sweep_rounded,
              label: 'Clear history',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(ctx);
                col.clearRecent();
              },
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String? title;
  const _TopBar({this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.maybePop(context)),
          if (title != null) ...[const SizedBox(width: 12), Text(title!, style: Theme.of(context).textTheme.titleLarge)],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final Track? cover;
  final bool circle;
  final bool wide;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final VoidCallback onMore;
  const _Header({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.cover,
    required this.circle,
    required this.wide,
    required this.onPlay,
    required this.onShuffle,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final size = wide ? 260.0 : 200.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, wide ? 60 : 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(circle ? size / 2 : 26),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 18))],
            ),
            child: ArtImage(track: cover, size: size, radius: 26, circle: circle),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(meta, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassIconButton(icon: Icons.shuffle_rounded, onPressed: onShuffle, size: 50, tooltip: 'Shuffle'),
              const SizedBox(width: 14),
              GlassIconButton(icon: Icons.play_arrow_rounded, onPressed: onPlay, size: 64, iconSize: 34, filled: true, tooltip: 'Play'),
              const SizedBox(width: 14),
              GlassIconButton(icon: Icons.more_horiz_rounded, onPressed: onMore, size: 50, tooltip: 'More'),
            ],
          ),
        ],
      ),
    );
  }
}
