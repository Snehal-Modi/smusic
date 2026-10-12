import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/glass.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import '../state/collections_state.dart';
import '../state/library_state.dart';
import '../state/online_state.dart';
import '../state/settings_state.dart';
import 'collection_page.dart';
import 'widgets/cards.dart';
import 'widgets/header.dart';

class HomePage extends StatelessWidget {
  final void Function(int tab, {int? libraryTab}) goToTab;
  const HomePage({super.key, required this.goToTab});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<SettingsState>().online;
    return online ? _OnlineHome(goToTab: goToTab) : _LocalHome(goToTab: goToTab);
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _QuickTile({required this.icon, required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GlassPanel(
        radius: 18,
        onTap: onTap,
        tint: filled ? accent : null,
        opacity: filled ? 0.8 : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: filled ? onAccent(accent) : Colors.white),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: filled ? onAccent(accent) : Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow();

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<CollectionsState>().recent;
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Jump back in',
            action: 'See all',
            onAction: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CollectionPage(kind: CollectionKind.recent)))),
        HorizontalRow(children: recent.take(12).map((t) => TrackCard(track: t, tracks: recent)).toList()),
      ],
    );
  }
}

class _LocalHome extends StatelessWidget {
  final void Function(int tab, {int? libraryTab}) goToTab;
  const _LocalHome({required this.goToTab});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryState>();
    final col = context.watch<CollectionsState>();
    final handler = context.read<SmusicAudioHandler>();
    final recent = lib.recentlyAdded;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () => lib.load(force: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          PageHeader(title: greeting(), subtitle: 'smusic  -  ${plural(lib.songs.length, 'song')} on this phone'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _QuickTile(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle all',
                  filled: true,
                  onTap: () => lib.songs.isEmpty ? null : handler.playAll(lib.songs, shuffleMode: true),
                ),
                const SizedBox(width: 10),
                _QuickTile(
                  icon: Icons.favorite_rounded,
                  label: 'Liked (${col.liked.length})',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const CollectionPage(kind: CollectionKind.liked))),
                ),
                const SizedBox(width: 10),
                _QuickTile(
                  icon: Icons.download_done_rounded,
                  label: 'Downloads',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const CollectionPage(kind: CollectionKind.downloads))),
                ),
              ],
            ),
          ),
          if (lib.loading && lib.songs.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (lib.denied)
            EmptyNote(
              icon: Icons.lock_outline_rounded,
              title: 'smusic needs permission to read your music',
              body: 'Allow access to audio files so your downloaded songs appear here.',
              action: FilledButton(onPressed: () => lib.load(force: true), child: const Text('Allow access')),
            )
          else if (lib.songs.isEmpty && lib.loaded)
            const EmptyNote(
              icon: Icons.library_music_outlined,
              title: 'No songs found on this phone',
              body: 'Copy MP3 / M4A / FLAC files anywhere on the phone, then pull down to refresh. Or switch to Online.',
            )
          else ...[
            const _RecentRow(),
            if (recent.isNotEmpty) ...[
              SectionTitle('Recently added', action: 'Songs', onAction: () => goToTab(2, libraryTab: 0)),
              HorizontalRow(children: recent.map((t) => TrackCard(track: t, tracks: recent)).toList()),
            ],
            if (lib.albums.isNotEmpty) ...[
              SectionTitle('Albums', action: 'See all', onAction: () => goToTab(2, libraryTab: 1)),
              HorizontalRow(
                children: lib.albums.take(15).map((g) => GroupCard(group: g, kind: CollectionKind.album)).toList(),
              ),
            ],
            if (lib.artists.isNotEmpty) ...[
              SectionTitle('Artists', action: 'See all', onAction: () => goToTab(2, libraryTab: 2)),
              HorizontalRow(
                height: 196,
                children: lib.artists.take(15).map((g) => GroupCard(group: g, kind: CollectionKind.artist, size: 130)).toList(),
              ),
            ],
            if (lib.folders.isNotEmpty) ...[
              SectionTitle('Folders', action: 'See all', onAction: () => goToTab(2, libraryTab: 3)),
              HorizontalRow(
                children: lib.folders.take(15).map((g) => GroupCard(group: g, kind: CollectionKind.folder)).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _OnlineHome extends StatefulWidget {
  final void Function(int tab, {int? libraryTab}) goToTab;
  const _OnlineHome({required this.goToTab});

  @override
  State<_OnlineHome> createState() => _OnlineHomeState();
}

class _OnlineHomeState extends State<_OnlineHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<OnlineState>().load());
  }

  Widget _row(String title, List<Track> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title,
            action: 'Play all', onAction: () => context.read<SmusicAudioHandler>().playAll(items)),
        HorizontalRow(children: items.map((t) => TrackCard(track: t, tracks: items)).toList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = context.watch<OnlineState>();
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () => on.load(force: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          PageHeader(title: greeting(), subtitle: 'smusic  -  streaming from everywhere'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassPanel(
              radius: 18,
              onTap: () => widget.goToTab(1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.8)),
                  const SizedBox(width: 10),
                  Text('Search songs, artists, radio...', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ],
              ),
            ),
          ),
          const _RecentRow(),
          if (on.loading && on.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (on.isEmpty && on.loaded)
            EmptyNote(
              icon: Icons.wifi_off_rounded,
              title: 'Could not reach any music source',
              body: 'Check your internet connection and pull down to retry. Search still works when a source is up.',
              action: FilledButton(onPressed: () => on.load(force: true), child: const Text('Retry')),
            )
          else ...[
            _row('Trending in India', on.saavnTrending),
            _row('Fresh on YouTube', on.youtubeNew),
            _row('Trending on Audius', on.audiusTrending),
            _row('Radio stations', on.radioTop),
          ],
        ],
      ),
    );
  }
}
