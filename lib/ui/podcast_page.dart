import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/glass.dart';
import '../models/podcast.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/podcast_service.dart';
import '../state/mood_state.dart';
import '../state/net_state.dart';
import '../state/podcast_state.dart';
import 'mini_player.dart';
import 'widgets/art.dart';
import 'widgets/cards.dart';
import 'widgets/header.dart';
import 'widgets/track_tile.dart';

/// Artwork stand-in so a show can reuse the shared [ArtImage] widget.
Track _showArt(Podcast p) => Track(
      id: 'pod-show:${p.id}',
      title: p.title,
      artist: p.author,
      album: '',
      source: TrackSource.podcast,
      artUrl: p.artUrl,
    );

/// Square card for a show, used in Home rows and browse grids.
class PodcastCard extends StatelessWidget {
  final Podcast podcast;
  final double size;
  const PodcastCard({super.key, required this.podcast, this.size = 148});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PodcastShowPage(podcast: podcast))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: ArtImage(track: _showArt(podcast), size: size, radius: 18),
            ),
            const SizedBox(height: 8),
            Text(podcast.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            Text(podcast.author,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final Widget child;
  const _Backdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final mood = context.watch<MoodState>();
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GlassBackdrop(accent: accent, mood: mood.color)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(child: child),
                const MiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Browse and search podcasts and stories.
class PodcastBrowsePage extends StatefulWidget {
  const PodcastBrowsePage({super.key});

  @override
  State<PodcastBrowsePage> createState() => _PodcastBrowsePageState();
}

class _PodcastBrowsePageState extends State<PodcastBrowsePage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Podcast> _shows = const [];
  bool _busy = true;
  int _category = -1; // -1 = top charts
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final gen = ++_gen;
    setState(() => _busy = true);
    final svc = context.read<PodcastService>();
    final q = _ctrl.text.trim();
    List<Podcast> res;
    if (q.isNotEmpty) {
      res = await svc.search(q);
    } else if (_category >= 0) {
      res = await svc.search(PodcastService.categories[_category].$2);
    } else {
      res = await svc.top(limit: 30);
    }
    if (!mounted || gen != _gen) return;
    setState(() {
      _shows = res;
      _busy = false;
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _category = -1;
      _run();
    });
  }

  @override
  Widget build(BuildContext context) {
    final followed = context.watch<PodcastState>().followed;
    final offline = !context.watch<NetState>().online;
    final searching = _ctrl.text.trim().isNotEmpty;

    return _Backdrop(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.maybePop(context)),
                const SizedBox(width: 12),
                Text('Podcasts and stories', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: GlassPanel(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onChanged: _onChanged,
                      onSubmitted: (_) {
                        _category = -1;
                        _run();
                      },
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search shows, stories, topics',
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (searching)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _ctrl.clear();
                        _run();
                      },
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              children: [
                GlassChip(
                  label: 'Top',
                  selected: _category == -1 && !searching,
                  onTap: () {
                    _ctrl.clear();
                    _category = -1;
                    _run();
                  },
                ),
                const SizedBox(width: 8),
                for (var i = 0; i < PodcastService.categories.length; i++) ...[
                  GlassChip(
                    label: PodcastService.categories[i].$1,
                    selected: _category == i && !searching,
                    onTap: () {
                      _ctrl.clear();
                      _category = i;
                      _run();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (followed.isNotEmpty && !searching && _category == -1) ...[
            const SectionTitle('Following'),
            HorizontalRow(children: followed.map((p) => PodcastCard(podcast: p)).toList()),
          ],
          SectionTitle(searching ? 'Results' : _category >= 0 ? PodcastService.categories[_category].$1 : 'Popular in India'),
          if (_busy)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_shows.isEmpty)
            EmptyNote(
              icon: offline ? Icons.wifi_off_rounded : Icons.podcasts_rounded,
              title: offline ? 'You are offline' : 'No shows found',
              body: offline ? 'Podcasts need internet. Downloaded episodes still play from Library.' : 'Try another word or category.',
              action: FilledButton(onPressed: _run, child: const Text('Try again')),
            )
          else
            ..._shows.map((p) => _ShowTile(podcast: p)),
        ],
      ),
    );
  }
}

class _ShowTile extends StatelessWidget {
  final Podcast podcast;
  const _ShowTile({required this.podcast});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PodcastShowPage(podcast: podcast))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            ArtImage(track: _showArt(podcast), size: 58, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(podcast.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(podcast.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

/// One show: follow it, play the latest episode, browse and download episodes.
class PodcastShowPage extends StatefulWidget {
  final Podcast podcast;
  const PodcastShowPage({super.key, required this.podcast});

  @override
  State<PodcastShowPage> createState() => _PodcastShowPageState();
}

class _PodcastShowPageState extends State<PodcastShowPage> {
  late Future<List<Track>> _episodes;

  @override
  void initState() {
    super.initState();
    _episodes = context.read<PodcastService>().episodes(widget.podcast);
  }

  void _retry() {
    setState(() => _episodes = context.read<PodcastService>().episodes(widget.podcast));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.podcast;
    final state = context.watch<PodcastState>();
    final following = state.isFollowed(p);
    final handler = context.read<SmusicAudioHandler>();
    final accent = Theme.of(context).colorScheme.primary;

    return _Backdrop(
      child: FutureBuilder<List<Track>>(
        future: _episodes,
        builder: (context, snap) {
          final eps = snap.data ?? const <Track>[];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(children: [GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.maybePop(context))]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 18))],
                        ),
                        child: ArtImage(track: _showArt(p), size: 190, radius: 26),
                      ),
                      const SizedBox(height: 16),
                      Text(p.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(p.author, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                      if (eps.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(plural(eps.length, 'episode'), style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => state.toggle(p),
                            icon: Icon(following ? Icons.check_rounded : Icons.add_rounded),
                            label: Text(following ? 'Following' : 'Follow'),
                          ),
                          const SizedBox(width: 14),
                          GlassIconButton(
                            icon: Icons.play_arrow_rounded,
                            size: 64,
                            iconSize: 34,
                            filled: true,
                            tooltip: 'Play latest',
                            onPressed: eps.isEmpty ? null : () => handler.playAll(eps),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (snap.connectionState != ConnectionState.done)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
              else if (eps.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyNote(
                    icon: Icons.podcasts_rounded,
                    title: 'Could not load episodes',
                    body: 'Check your internet connection and try again.',
                    action: FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: eps.length,
                  itemBuilder: (c, i) => TrackTile(track: eps[i], queueContext: eps),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}
