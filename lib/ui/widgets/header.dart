import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/glass.dart';
import '../../state/settings_state.dart';

/// The Local / Online switch. Lives at the top of every main page.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final accent = Theme.of(context).colorScheme.primary;
    final online = settings.online;
    const w = 168.0;
    const h = 38.0;
    return GlassPanel(
      radius: h / 2,
      width: w,
      height: h,
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: online ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: (w - 6) / 2,
              height: h - 6,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(h / 2),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4))],
              ),
            ),
          ),
          Row(
            children: [
              _seg(context, 'Local', Icons.phone_android_rounded, !online, () => settings.setOnline(false), accent),
              _seg(context, 'Online', Icons.public_rounded, online, () => settings.setOnline(true), accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seg(BuildContext c, String label, IconData icon, bool active, VoidCallback onTap, Color accent) {
    final color = active ? onAccent(accent) : Colors.white.withOpacity(0.75);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showSwitch;
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const [], this.showSwitch = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w600)),
                Text(title, style: Theme.of(context).textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ...actions,
          if (showSwitch) ...[const SizedBox(width: 8), const ModeSwitch()],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// Empty-state card used on every page.
class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  const EmptyNote({super.key, required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: Colors.white.withOpacity(0.7)),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              if (body != null) ...[
                const SizedBox(height: 6),
                Text(body!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}
