import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../services/audio_handler.dart';
import 'widgets/sheets.dart';

Future<void> showEqualizerSheet(BuildContext context) => showGlassSheet(context, builder: (_) => const EqualizerSheet());

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  double _bass = 0;

  static const _presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0],
    'Bass boost': [6, 4, 0, 0, 1],
    'Vocal': [-2, 0, 3, 4, 1],
    'Treble': [0, 0, 1, 4, 6],
    'Rock': [4, 2, -1, 2, 4],
    'Pop': [-1, 2, 4, 2, -1],
  };

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    final eq = handler.equalizer;
    final accent = Theme.of(context).colorScheme.primary;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Expanded(child: Text('Equalizer', style: Theme.of(context).textTheme.titleLarge)),
            StreamBuilder<bool>(
              stream: eq.enabledStream,
              builder: (c, s) => Switch(
                value: s.data ?? false,
                onChanged: (v) => eq.setEnabled(v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FutureBuilder<AndroidEqualizerParameters>(
          future: eq.parameters,
          builder: (c, s) {
            final p = s.data;
            if (p == null) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            return Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _presets.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(e.key),
                                backgroundColor: Colors.white.withOpacity(0.08),
                                side: BorderSide.none,
                                onPressed: () async {
                                  await eq.setEnabled(true);
                                  for (int i = 0; i < p.bands.length; i++) {
                                    final g = e.value[(i * e.value.length / p.bands.length).floor().clamp(0, e.value.length - 1).toInt()];
                                    await p.bands[i].setGain(g.clamp(p.minDecibels, p.maxDecibels).toDouble());
                                  }
                                  setState(() {});
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: Row(
                    children: p.bands
                        .map((b) => Expanded(
                              child: StreamBuilder<double>(
                                stream: b.gainStream,
                                builder: (c, gs) {
                                  final g = gs.data ?? b.gain;
                                  return Column(
                                    children: [
                                      Text('${g >= 0 ? '+' : ''}${g.toStringAsFixed(0)}',
                                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                                      Expanded(
                                        child: RotatedBox(
                                          quarterTurns: -1,
                                          child: Slider(
                                            value: g.clamp(p.minDecibels, p.maxDecibels).toDouble(),
                                            min: p.minDecibels,
                                            max: p.maxDecibels,
                                            activeColor: accent,
                                            onChanged: (v) => b.setGain(v),
                                          ),
                                        ),
                                      ),
                                      Text(_hz(b.centerFrequency), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                                    ],
                                  );
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
        const Divider(height: 24),
        Row(
          children: [
            const Icon(Icons.graphic_eq_rounded, color: Colors.white70),
            const SizedBox(width: 12),
            Text('Loudness boost  ${_bass.toStringAsFixed(0)} dB', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          value: _bass,
          min: 0,
          max: 15,
          divisions: 15,
          onChanged: (v) async {
            setState(() => _bass = v);
            await handler.loudness.setEnabled(v > 0);
            await handler.loudness.setTargetGain(v);
          },
        ),
        Text('Boost quietly recorded songs. Keep low to avoid distortion.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  static String _hz(double hz) => hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k' : hz.toStringAsFixed(0);
}
