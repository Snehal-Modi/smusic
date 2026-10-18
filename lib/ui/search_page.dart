import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/glass.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/sources/music_source.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import 'widgets/header.dart';
import 'widgets/track_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool _busy = false;
  String _lastQuery = '';
  Map<TrackSource, List<Track>> _online = {};
  List<Track> _local = const [];
  TrackSource? _filter; // null = all

  static const _filters = [TrackSource.saavn, TrackSource.youtube, TrackSource.audius, TrackSource.radio];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final settings = context.read<SettingsState>();
    if (!settings.online) {
      setState(() {
        _local = context.read<LibraryState>().search(v);
        _lastQuery = v;
      });
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), () => _runOnline(v));
  }

  Future<void> _runOnline(String q) async {
    final s = q.trim();
    if (s.isEmpty) {
      setState(() {
        _online = {};
        _lastQuery = '';
      });
      return;
    }
    setState(() {
      _busy = true;
      _lastQuery = s;
    });
    final res = await Sources.searchAll(s, only: _filter == null ? null : {_filter!});
    if (!mounted || _lastQuery != s) return;
    context.read<SettingsState>().addSearch(s);
    setState(() {
      _online = res;
      _busy = false;
    });
  }

  void _submit(String v) {
    _debounce?.cancel();
    if (context.read<SettingsState>().online) {
      _runOnline(v);
    } else {
      _onChanged(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final online = settings.online;
    final accent = Theme.of(context).colorScheme.primary;
    final handler = context.read<SmusicAudioHandler>();

    final all = <Track>[];
    for (final s in _filters) {
      all.addAll(_online[s] ?? const []);
    }

    return Column(
      children: [
        const PageHeader(title: 'Search'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onSubmitted: _submit,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: online ? 'Songs, artists, radio stations...' : 'Search your songs',
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_busy)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else if (_ctrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _ctrl.clear();
                      _onChanged('');
                      _runOnline('');
                    },
                  ),
              ],
            ),
          ),
        ),
        if (online)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              children: [
                GlassChip(label: 'All', selected: _filter == null, onTap: () => _setFilter(null)),
                const SizedBox(width: 8),
                for (final f in _filters) ...[
                  GlassChip(
                    label: sourceLabel(f),
                    icon: sourceIcon(f),
                    selected: _filter == f,
                    onTap: () => _setFilter(f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        Expanded(
          child: _lastQuery.trim().isEmpty
              ? _history(settings)
              : online
                  ? _onlineResults(all, accent, handler)
                  : _localResults(handler),
        ),
      ],
    );
  }

  void _setFilter(TrackSource? f) {
    setState(() => _filter = f);
    if (_lastQuery.isNotEmpty) _runOnline(_lastQuery);
  }

  Widget _history(SettingsState settings) {
    if (settings.searchHistory.isEmpty) {
      return EmptyNote(
        icon: Icons.search_rounded,
        title: settings.online ? 'Search everywhere at once' : 'Find songs on this phone',
        body: settings.online
            ? 'JioSaavn, YouTube, Audius and 30,000 radio stations. Results show grouped by source.'
            : 'Type a song, artist or album name.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Row(
          children: [
            Expanded(child: Text('Recent searches', style: Theme.of(context).textTheme.titleMedium)),
            TextButton(onPressed: settings.clearSearchHistory, child: const Text('Clear')),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: settings.searchHistory
              .map((h) => GlassChip(
                    label: h,
                    icon: Icons.history_rounded,
                    onTap: () {
                      _ctrl.text = h;
                      _submit(h);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _localResults(SmusicAudioHandler handler) {
    if (_local.isEmpty) {
      return const EmptyNote(icon: Icons.search_off_rounded, title: 'No matches on this phone', body: 'Try Online mode to stream it instead.');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: _local.length,
      itemBuilder: (c, i) => TrackTile(track: _local[i], queueContext: _local),
    );
  }

  Widget _onlineResults(List<Track> all, Color accent, SmusicAudioHandler handler) {
    if (_busy && all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (all.isEmpty) {
      return const EmptyNote(
        icon: Icons.cloud_off_rounded,
        title: 'Nothing found',
        body: 'Try another spelling, or pick a different source chip. Some sources are blocked on some networks.',
      );
    }
    final sections = <Widget>[];
    for (final s in _filters) {
      final list = _online[s] ?? const [];
      if (list.isEmpty) continue;
      sections.add(SectionTitle(sourceLabel(s), action: 'Play all', onAction: () => handler.playAll(list)));
      sections.addAll(list.map((t) => TrackTile(track: t, queueContext: list)));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 120), children: sections);
  }
}
