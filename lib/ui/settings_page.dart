import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/glass.dart';
import '../core/theme.dart';
import '../services/download_service.dart';
import '../services/local_library.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import 'equalizer_sheet.dart';
import 'widgets/header.dart';
import 'widgets/sheets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final accent = s.accent;
    final hsv = HSVColor.fromColor(accent);

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        const PageHeader(title: 'Settings', showSwitch: false),
        _Card(title: 'Accent colour', children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kAccentPresets
                  .map((c) => GestureDetector(
                        onTap: () => s.setAccent(c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: c.value == accent.value ? 3 : 0),
                            boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 12)],
                          ),
                          child: c.value == accent.value ? Icon(Icons.check_rounded, color: onAccent(c), size: 20) : null,
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            dense: true,
            title: const Text('Custom hue'),
            subtitle: ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [
                Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000)
              ]).createShader(r),
              child: Slider(
                value: hsv.hue,
                max: 360,
                activeColor: Colors.white,
                inactiveColor: Colors.white,
                onChanged: (h) => s.setAccent(HSVColor.fromAHSV(1, h, hsv.saturation < 0.25 ? 0.75 : hsv.saturation, hsv.value < 0.6 ? 0.95 : hsv.value).toColor()),
              ),
            ),
          ),
          ListTile(
            dense: true,
            title: const Text('Brightness'),
            subtitle: Slider(
              value: hsv.value,
              min: 0.4,
              max: 1,
              onChanged: (v) => s.setAccent(hsv.withValue(v).toColor()),
            ),
          ),
        ]),
        _Card(title: 'Glass look', children: [
          ListTile(
            dense: true,
            title: Text('Blur strength  ${s.blur.toStringAsFixed(0)}'),
            subtitle: Slider(value: s.blur, min: 0, max: 40, onChanged: s.setBlur),
          ),
          ListTile(
            dense: true,
            title: Text('Glass opacity  ${(s.glassOpacity * 100).toStringAsFixed(0)}%'),
            subtitle: Slider(value: s.glassOpacity, min: 0.03, max: 0.3, onChanged: s.setGlassOpacity),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Mood colours from album art'),
            subtitle: const Text('Background follows the playing song'),
            value: s.moodColors,
            onChanged: s.setMoodColors,
          ),
        ]),
        _Card(title: 'Streaming', children: [
          SwitchListTile(
            dense: true,
            title: const Text('Data saver'),
            subtitle: const Text('Low quality streams (about 96 kbps). Good for slow internet.'),
            value: s.lowQuality,
            onChanged: s.setLowQuality,
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Large buffer'),
            subtitle: const Text('Pre-loads up to 4 minutes ahead. Fewer pauses on weak signal. Takes effect after restart.'),
            value: s.bigBuffer,
            onChanged: s.setBigBuffer,
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Cache streamed songs'),
            subtitle: const Text('Replays do not download again. Turn off if a source refuses to play.'),
            value: s.cacheStreams,
            onChanged: s.setCacheStreams,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.cleaning_services_rounded),
            title: const Text('Clear stream cache'),
            onTap: () async {
              try {
                final tmp = await getTemporaryDirectory();
                final d = Directory('${tmp.path}/just_audio_cache');
                if (await d.exists()) await d.delete(recursive: true);
                context.read<LocalLibrary>().clearArtCache();
                if (context.mounted) snack(context, 'Cache cleared');
              } catch (_) {
                if (context.mounted) snack(context, 'Nothing to clear');
              }
            },
          ),
        ]),
        _Card(title: 'Sound', children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.equalizer_rounded),
            title: const Text('Equalizer and loudness'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showEqualizerSheet(context),
          ),
        ]),
        _Card(title: 'Library', children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Rescan songs on this phone'),
            onTap: () {
              context.read<LibraryState>().load(force: true);
              snack(context, 'Rescanning...');
            },
          ),
          Consumer<DownloadService>(
            builder: (c, dl, _) => ListTile(
              dense: true,
              leading: const Icon(Icons.download_done_rounded),
              title: Text('${dl.downloads.length} downloaded songs'),
              subtitle: const Text('Stored privately inside the app'),
            ),
          ),
        ]),
        _Card(title: 'About', children: [
          const ListTile(
            dense: true,
            leading: Icon(Icons.music_note_rounded),
            title: Text('smusic 1.0.0'),
            subtitle: Text('Local + online music player. Open source, distributed through GitHub only.'),
          ),
          ListTile(
            dense: true,
            leading: Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.6)),
            title: const Text('Sources'),
            subtitle: const Text(
                'Your phone, JioSaavn, YouTube, Audius and radio-browser. YouTube and JioSaavn are unofficial and may need an app update when they change.'),
          ),
        ]),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
