import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/glass.dart';
import '../models/podcast.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/download_service.dart';
import '../services/reco_service.dart';
import '../state/collections_state.dart';
import '../state/library_state.dart';
import '../state/net_state.dart';
import '../state/online_state.dart';
import '../state/podcast_state.dart';
import '../state/settings_state.dart';
import 'collection_page.dart';
import 'podcast_page.dart';
import 'widgets/art.dart';
import 'widgets/cards.dart';
import 'widgets/header.dart';

class HomePage extends StatelessWidget {
  final void Function(int tab, {int? libraryTab}) goToTab;
  const HomePage({super.key, required this.goToTab});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<SettingsState>().online;
    final connected = context.watch<NetState>().online;
    if (!online) return _LocalHome(goToTab: goToTab);
    // No internet: show what is saved on the phone instead of empty online rows.
    return connected ? _OnlineHome(goToTab: goToTab) : _OfflineHome(goToTab: goToTab);
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
          PageHeader(title: greeting(), subtitle: '${plural(lib.songs.length, 'song')} on this phone'),
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
              body: lib.permanentlyDenied
                  ? 'Permission was turned off. Open the app settings and allow "Music and audio".'
                  : 'Allow access to audio files so your downloaded songs appear here.',
              action: Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
                FilledButton(onPressed: () => lib.load(force: true), child: const Text('Allow access')),
                if (lib.permanentlyDenied) TextButton(onPressed: openAppSettings, child: const Text('Open settings')),
              ]),
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

/// First-run card: which languages does the listener want music in?
class _LanguagePrompt extends StatefulWidget {
  const _LanguagePrompt();

  @override
  State<_LanguagePrompt> createState() => _LanguagePromptState();
}

class _LanguagePromptState extends State<_LanguagePrompt> {
  late final List<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = List.of(context.read<SettingsState>().languages);
  }

  void _toggle(String l) {
    setState(() {
      if (!_picked.remove(l)) _picked.add(l);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What do you listen to?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Pick your languages. Home and the suggestions follow them. The first one you pick comes first.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kLanguages
                  .map((l) => GlassChip(label: langLabel(l), selected: _picked.contains(l), onTap: () => _toggle(l)))
                  .toList(),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _picked.isEmpty ? null : () => context.read<SettingsState>().setLanguages(_picked),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A personal mix: tap to play it.
class _MixCard extends StatelessWidget {
  final Mix mix;
  final double size;
  const _MixCard({required this.mix, this.size = 148});

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => handler.playAll(mix.tracks),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Stack(
                children: [
                  ArtImage(track: mix.tracks.first, size: size, radius: 18),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow_rounded, color: onAccent(accent)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(mix.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            Text(mix.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
          ],
        ),
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
  late String _langKey;

  @override
  void initState() {
    super.initState();
    _langKey = context.read<SettingsState>().languages.join(',');
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<OnlineState>().load());
  }

  Widget _row(String title, List<Track> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title, action: 'Play all', onAction: () => context.read<SmusicAudioHandler>().playAll(items)),
        HorizontalRow(children: items.map((t) => TrackCard(track: t, tracks: items)).toList()),
      ],
    );
  }

  Widget _shows(String title, List<Podcast> shows, {bool browse = true}) {
    if (shows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title,
            action: browse ? 'Browse' : null,
            onAction: browse ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PodcastBrowsePage())) : null),
        HorizontalRow(children: shows.map((p) => PodcastCard(podcast: p)).toList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = context.watch<OnlineState>();
    final settings = context.watch<SettingsState>();
    final col = context.watch<CollectionsState>();
    final followed = context.watch<PodcastState>().followed;

    // Languages changed in Settings or on the first-run card: refresh the rows.
    final key = settings.languages.join(',');
    if (key != _langKey) {
      _langKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<OnlineState>().load();
      });
    }

    final langs = settings.languages.take(4).toList();
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () => on.load(force: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          PageHeader(title: greeting(), subtitle: settings.languages.map(langLabel).take(3).join(', ')),
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
                  Text('Search songs, artists, podcasts...', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _QuickTile(
                  icon: Icons.podcasts_rounded,
                  label: 'Podcasts',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PodcastBrowsePage())),
                ),
                const SizedBox(width: 10),
                _QuickTile(
                  icon: Icons.favorite_rounded,
                  label: 'Liked (${col.liked.length})',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionPage(kind: CollectionKind.liked))),
                ),
                const SizedBox(width: 10),
                _QuickTile(
                  icon: Icons.download_done_rounded,
                  label: 'Downloads',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionPage(kind: CollectionKind.downloads))),
                ),
              ],
            ),
          ),
          if (!settings.languagesChosen) const _LanguagePrompt(),
          const _RecentRow(),
          if (on.loading && on.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (on.isEmpty && on.loaded)
            EmptyNote(
              icon: Icons.cloud_off_rounded,
              title: 'Could not reach any music source',
              body: 'Pull down to retry. Search still works when a source is up.',
              action: FilledButton(onPressed: () => on.load(force: true), child: const Text('Retry')),
            )
          else ...[
            if (on.mixes.isNotEmpty) ...[
              const SectionTitle('Made for you'),
              HorizontalRow(children: on.mixes.map((m) => _MixCard(mix: m)).toList()),
            ],
            if (on.becauseTracks.isNotEmpty) _row('Because you listened to ${on.becauseArtist}', on.becauseTracks),
            for (var i = 0; i < langs.length; i++) ...[
              _row('Trending in ${langLabel(langs[i])}', on.languageRows[langs[i]] ?? const []),
              _row('Top 50 ${langLabel(langs[i])}', on.languageCharts[langs[i]] ?? const []),
            ],
            _shows('Your podcasts', followed, browse: false),
            _shows('Podcasts for you', on.topPodcasts),
            _shows('Stories and kahani', on.storyShows),
            _row('Fresh on YouTube', on.youtubeNew),
            _row('Trending on Audius', on.audiusTrending),
            _row('Radio stations', on.radioTop),
          ],
        ],
      ),
    );
  }
}

/// Home when there is no internet: everything saved on the phone, front and centre.
class _OfflineHome extends StatelessWidget {
  final void Function(int tab, {int? libraryTab}) goToTab;
  const _OfflineHome({required this.goToTab});

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadService>();
    final col = context.watch<CollectionsState>();
    final lib = context.watch<LibraryState>();
    final handler = context.read<SmusicAudioHandler>();
    final net = context.read<NetState>();

    bool playable(Track t) => t.isLocal || dl.isDownloaded(t);
    final downloads = dl.downloads;
    final recent = col.recent.where(playable).take(12).toList();
    final liked = col.liked.where(playable).toList();
    final phone = lib.recentlyAdded;
    final nothing = downloads.isEmpty && liked.isEmpty && phone.isEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        PageHeader(title: greeting(), subtitle: 'You are offline'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassPanel(
            radius: 18,
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('No internet. Playing what is saved on this phone.',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13.5)),
                ),
                TextButton(onPressed: net.check, child: const Text('Retry')),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _QuickTile(
                icon: Icons.shuffle_rounded,
                label: 'Shuffle offline',
                filled: true,
                onTap: () {
                  final all = <Track>[...downloads, ...lib.songs];
                  if (all.isNotEmpty) handler.playAll(all, shuffleMode: true);
                },
              ),
              const SizedBox(width: 10),
              _QuickTile(
                icon: Icons.favorite_rounded,
                label: 'Liked (${liked.length})',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionPage(kind: CollectionKind.liked))),
              ),
              const SizedBox(width: 10),
              _QuickTile(
                icon: Icons.download_done_rounded,
                label: 'Downloads',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionPage(kind: CollectionKind.downloads))),
              ),
            ],
          ),
        ),
        if (nothing)
          const EmptyNote(
            icon: Icons.download_for_offline_outlined,
            title: 'Nothing saved for offline yet',
            body: 'When you are online, long-press any song and choose Download for offline. It will show up here automatically.',
          )
        else ...[
          if (downloads.isNotEmpty) ...[
            SectionTitle('Downloaded', action: 'Play all', onAction: () => handler.playAll(downloads)),
            HorizontalRow(children: downloads.take(20).map((t) => TrackCard(track: t, tracks: downloads)).toList()),
          ],
          if (recent.isNotEmpty) ...[
            const SectionTitle('Jump back in'),
            HorizontalRow(children: recent.map((t) => TrackCard(track: t, tracks: recent)).toList()),
          ],
          if (liked.isNotEmpty) ...[
            SectionTitle('Liked and saved', action: 'Play all', onAction: () => handler.playAll(liked)),
            HorizontalRow(children: liked.take(20).map((t) => TrackCard(track: t, tracks: liked)).toList()),
          ],
          if (phone.isNotEmpty) ...[
            SectionTitle('On this phone', action: 'Songs', onAction: () => goToTab(2, libraryTab: 0)),
            HorizontalRow(children: phone.map((t) => TrackCard(track: t, tracks: phone)).toList()),
          ],
        ],
      ],
    );
  }
}
