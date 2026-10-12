import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/glass.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/download_service.dart';
import '../state/collections_state.dart';
import '../state/library_state.dart';
import 'collection_page.dart';
import 'widgets/art.dart';
import 'widgets/cards.dart';
import 'widgets/header.dart';
import 'widgets/sheets.dart';
import 'widgets/track_tile.dart';

class LibraryPage extends StatefulWidget {
  final int initialTab;
  const LibraryPage({super.key, this.initialTab = 0});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 8, vsync: this, initialIndex: widget.initialTab);

  @override
  void didUpdateWidget(covariant LibraryPage old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) _tabs.animateTo(widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryState>();
    final col = context.watch<CollectionsState>();
    final dl = context.watch<DownloadService>();
    final handler = context.read<SmusicAudioHandler>();

    return Column(
      children: [
        PageHeader(
          title: 'Your library',
          actions: [
            GlassIconButton(
              icon: Icons.refresh_rounded,
              size: 38,
              iconSize: 19,
              tooltip: 'Rescan phone',
              onPressed: () => lib.load(force: true),
            ),
          ],
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
            Tab(text: 'Folders'),
            Tab(text: 'Playlists'),
            Tab(text: 'Liked'),
            Tab(text: 'Downloads'),
            Tab(text: 'History'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _songs(lib, handler),
              lib.denied ? _denied(lib) : GroupGrid(groups: lib.albums, kind: CollectionKind.album),
              lib.denied ? _denied(lib) : GroupGrid(groups: lib.artists, kind: CollectionKind.artist),
              lib.denied ? _denied(lib) : GroupGrid(groups: lib.folders, kind: CollectionKind.folder),
              _playlists(col),
              _plain(col.liked, 'No liked songs yet', 'Tap the heart on any song.', handler, onRemove: col.toggleLike),
              _downloads(dl, handler),
              _plain(col.recent, 'Nothing played yet', 'Your listening history appears here.', handler),
            ],
          ),
        ),
      ],
    );
  }

  Widget _denied(LibraryState lib) => EmptyNote(
        icon: Icons.lock_outline_rounded,
        title: 'Permission needed',
        body: 'Allow smusic to read audio files on this phone.',
        action: Wrap(spacing: 8, children: [
          FilledButton(onPressed: () => lib.load(force: true), child: const Text('Allow')),
          TextButton(onPressed: openAppSettings, child: const Text('Open settings')),
        ]),
      );

  Widget _songs(LibraryState lib, SmusicAudioHandler handler) {
    if (lib.denied) return _denied(lib);
    if (lib.loading && lib.songs.isEmpty) return const Center(child: CircularProgressIndicator());
    if (lib.songs.isEmpty) {
      return const EmptyNote(icon: Icons.library_music_outlined, title: 'No songs on this phone', body: 'Pull to refresh after adding music files.');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: lib.songs.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(plural(lib.songs.length, 'song'), style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                GlassChip(label: 'Play all', icon: Icons.play_arrow_rounded, onTap: () => handler.playAll(lib.songs)),
                const SizedBox(width: 8),
                GlassChip(label: 'Shuffle', icon: Icons.shuffle_rounded, selected: true, onTap: () => handler.playAll(lib.songs, shuffleMode: true)),
              ],
            ),
          );
        }
        final t = lib.songs[i - 1];
        return TrackTile(track: t, queueContext: lib.songs);
      },
    );
  }

  Widget _plain(List<Track> tracks, String emptyTitle, String emptyBody, SmusicAudioHandler handler, {void Function(Track)? onRemove}) {
    if (tracks.isEmpty) return EmptyNote(icon: Icons.music_off_rounded, title: emptyTitle, body: emptyBody);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: tracks.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(plural(tracks.length, 'song'), style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                GlassChip(label: 'Play all', icon: Icons.play_arrow_rounded, onTap: () => handler.playAll(tracks)),
                const SizedBox(width: 8),
                GlassChip(label: 'Shuffle', icon: Icons.shuffle_rounded, selected: true, onTap: () => handler.playAll(tracks, shuffleMode: true)),
              ],
            ),
          );
        }
        final t = tracks[i - 1];
        return TrackTile(track: t, queueContext: tracks, showSource: true, onRemove: onRemove == null ? null : () => onRemove(t));
      },
    );
  }

  Widget _downloads(DownloadService dl, SmusicAudioHandler handler) {
    final active = dl.progress.entries.toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        for (final e in active)
          ListTile(
            leading: const Icon(Icons.downloading_rounded),
            title: Text('Downloading...', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: LinearProgressIndicator(value: e.value == 0 ? null : e.value, minHeight: 4, borderRadius: BorderRadius.circular(2)),
          ),
        if (dl.downloads.isEmpty && active.isEmpty)
          const EmptyNote(
            icon: Icons.download_rounded,
            title: 'Nothing downloaded yet',
            body: 'Open any online song menu and choose Download for offline. Downloads play without internet.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(plural(dl.downloads.length, 'download'), style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                GlassChip(label: 'Play all', icon: Icons.play_arrow_rounded, onTap: () => handler.playAll(dl.downloads)),
              ],
            ),
          ),
          ...dl.downloads.map((t) => TrackTile(track: t, queueContext: dl.downloads, showSource: true)),
        ],
      ],
    );
  }

  Widget _playlists(CollectionsState col) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
      children: [
        GlassPanel(
          radius: 16,
          margin: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          onTap: () async {
            final name = await askText(context, title: 'New playlist', hint: 'Playlist name');
            if (name != null) col.createPlaylist(name);
          },
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: const Row(children: [Icon(Icons.add_rounded), SizedBox(width: 10), Text('Create playlist', style: TextStyle(fontWeight: FontWeight.w700))]),
        ),
        if (col.playlists.isEmpty)
          const EmptyNote(icon: Icons.queue_music_rounded, title: 'No playlists yet', body: 'Create one, then long-press songs to add them.'),
        ...col.playlists.map((p) => ListTile(
              leading: ArtImage(track: p.tracks.isEmpty ? null : p.tracks.first, size: 54, radius: 12),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(plural(p.tracks.length, 'song')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => CollectionPage(kind: CollectionKind.playlist, playlistId: p.id))),
            )),
      ],
    );
  }
}
