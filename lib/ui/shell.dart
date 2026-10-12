import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/glass.dart';
import '../state/library_state.dart';
import '../state/mood_state.dart';
import '../state/settings_state.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'mini_player.dart';
import 'search_page.dart';
import 'settings_page.dart';

/// Root layout: backdrop, pages, mini player, glass navigation.
/// Bottom bar on phones, side rail on tablets / landscape.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _libraryTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<LibraryState>().load());
  }

  void _go(int tab, {int? libraryTab}) {
    setState(() {
      _tab = tab;
      if (libraryTab != null) _libraryTab = libraryTab;
    });
  }

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.search_rounded, Icons.search_outlined, 'Search'),
    (Icons.library_music_rounded, Icons.library_music_outlined, 'Library'),
    (Icons.tune_rounded, Icons.tune_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final mood = context.watch<MoodState>();
    final accent = settings.accent;

    final pages = IndexedStack(
      index: _tab,
      children: [
        HomePage(goToTab: _go),
        const SearchPage(),
        LibraryPage(initialTab: _libraryTab),
        const SettingsPage(),
      ],
    );

    return GlassConfig(
      blur: settings.blur,
      opacity: settings.glassOpacity,
      child: Scaffold(
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GlassBackdrop(accent: accent, mood: settings.moodColors ? mood.color : null),
            LayoutBuilder(builder: (c, box) {
              final wide = box.maxWidth >= 840;
              if (wide) {
                return SafeArea(
                  child: Row(
                    children: [
                      _Rail(tab: _tab, onTap: (i) => _go(i), items: _items),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: pages),
                            const MiniPlayer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(child: pages),
                    const MiniPlayer(),
                    _BottomBar(tab: _tab, onTap: (i) => _go(i), items: _items),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;
  const _BottomBar({required this.tab, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final pad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 8 + pad),
      child: GlassPanel(
        radius: 26,
        tint: const Color(0xFF2A2A44),
        opacity: 0.5,
        blur: 26,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: List.generate(items.length, (i) {
            final active = i == tab;
            final it = items[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? accent.withOpacity(0.22) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(active ? it.$1 : it.$2, color: active ? accent : Colors.white.withOpacity(0.7), size: 24),
                    ),
                    const SizedBox(height: 2),
                    Text(it.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                          color: active ? Colors.white : Colors.white.withOpacity(0.6),
                        )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;
  const _Rail({required this.tab, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: GlassPanel(
        radius: 26,
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(Icons.music_note_rounded, color: accent, size: 30),
            const SizedBox(height: 24),
            ...List.generate(items.length, (i) {
              final active = i == tab;
              final it = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? accent.withOpacity(0.22) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(active ? it.$1 : it.$2, color: active ? accent : Colors.white.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 2),
                      Text(it.$3, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(active ? 1 : 0.6))),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
