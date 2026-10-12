import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/glass.dart';
import '../../models/track.dart';
import '../../state/collections_state.dart';

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

/// Bottom sheet wrapped in glass. [builder] gets the sheet's own context.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? maxHeightFraction,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height * (maxHeightFraction ?? 0.85);
      return Padding(
        padding: EdgeInsets.only(left: 10, right: 10, bottom: 10 + MediaQuery.of(ctx).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h),
          child: GlassPanel(
            radius: 28,
            tint: const Color(0xFF2A2A44),
            opacity: 0.55,
            blur: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;
  const SheetItem({super.key, required this.icon, required this.label, this.sub, this.onTap, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white.withOpacity(0.85)),
      title: Text(label, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w600)),
      subtitle: sub == null ? null : Text(sub!, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
      dense: true,
    );
  }
}

Future<String?> askText(BuildContext context, {required String title, String? initial, String hint = ''}) async {
  final c = TextEditingController(text: initial ?? '');
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
      ],
    ),
  );
  return r == null || r.trim().isEmpty ? null : r.trim();
}

Future<bool> confirm(BuildContext context, String title, {String yes = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}

/// Lets the user pick (or create) a playlist and adds [tracks] to it.
Future<void> pickPlaylist(BuildContext context, List<Track> tracks) async {
  final col = context.read<CollectionsState>();
  await showGlassSheet(
    context,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text('Add to playlist', style: Theme.of(ctx).textTheme.titleLarge),
        ),
        SheetItem(
          icon: Icons.add_rounded,
          label: 'New playlist',
          onTap: () async {
            Navigator.pop(ctx);
            final name = await askText(context, title: 'New playlist', hint: 'Playlist name');
            if (name == null) return;
            final p = col.createPlaylist(name);
            col.addAllToPlaylist(p.id, tracks);
            if (context.mounted) snack(context, 'Added to "${p.name}"');
          },
        ),
        ...col.playlists.map((p) => SheetItem(
              icon: Icons.queue_music_rounded,
              label: p.name,
              sub: '${p.tracks.length} songs',
              onTap: () {
                col.addAllToPlaylist(p.id, tracks);
                Navigator.pop(ctx);
                snack(context, 'Added to "${p.name}"');
              },
            )),
      ],
    ),
  );
}
