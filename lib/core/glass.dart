import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared glass intensity, set once from Settings at the top of the tree.
class GlassConfig extends InheritedWidget {
  final double blur;
  final double opacity;
  const GlassConfig({super.key, required this.blur, required this.opacity, required super.child});

  static GlassConfig? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<GlassConfig>();

  @override
  bool updateShouldNotify(GlassConfig old) => old.blur != blur || old.opacity != opacity;
}

/// A frosted, translucent panel: the building block of the whole UI.
///
/// [frosted] controls the real backdrop blur. It is expensive, so small
/// repeated elements (chips, round buttons, list rows) turn it off and rely on
/// the translucent fill alone, which looks the same at that size.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final double? blur;
  final double? opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  final bool border;
  final bool highlight;
  final bool frosted;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur,
    this.opacity,
    this.padding,
    this.margin,
    this.tint,
    this.border = true,
    this.highlight = true,
    this.frosted = true,
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = GlassConfig.maybeOf(context);
    final b = blur ?? cfg?.blur ?? 18;
    final o = opacity ?? cfg?.opacity ?? 0.10;
    final base = tint ?? Colors.white;
    final r = BorderRadius.circular(radius);
    final useBlur = frosted && b > 0.5;
    // Without the blur a little more fill keeps the panel readable.
    final fill = useBlur ? o : o + 0.04;

    Widget inner = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withOpacity((fill + (highlight ? 0.06 : 0)).clamp(0.0, 1.0)),
            base.withOpacity((fill * 0.55).clamp(0.0, 1.0)),
          ],
        ),
        border: border ? Border.all(color: Colors.white.withOpacity(0.14), width: 1) : null,
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      inner = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: r,
          splashColor: Colors.white.withOpacity(0.08),
          highlightColor: Colors.white.withOpacity(0.05),
          child: inner,
        ),
      );
    }

    final clipped = ClipRRect(
      borderRadius: r,
      child: useBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: b, sigmaY: b),
              child: inner,
            )
          : inner,
    );

    return margin != null ? Padding(padding: margin!, child: clipped) : clipped;
  }
}

/// Round glass icon button used all over the player.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;
  final String? tooltip;
  final bool filled;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.color,
    this.background,
    this.tooltip,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = GlassPanel(
      radius: size / 2,
      width: size,
      height: size,
      frosted: false,
      tint: filled ? scheme.primary : background,
      opacity: filled ? 0.9 : null,
      onTap: onPressed,
      child: Center(
        child: Icon(icon,
            size: iconSize,
            color: color ?? (filled ? _onAccent(scheme.primary) : Colors.white.withOpacity(onPressed == null ? 0.35 : 0.92))),
      ),
    );
    final sem = Semantics(button: true, label: tooltip, child: btn);
    return tooltip == null ? sem : Tooltip(message: tooltip!, child: sem);
  }
}

Color _onAccent(Color accent) => accent.computeLuminance() > 0.5 ? const Color(0xFF101018) : Colors.white;

Color onAccent(Color accent) => _onAccent(accent);

/// Pill shaped chip, optionally selected (filled with accent).
class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  const GlassChip({super.key, required this.label, this.selected = false, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      radius: 999,
      frosted: false,
      tint: selected ? scheme.primary : null,
      opacity: selected ? 0.85 : null,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: selected ? _onAccent(scheme.primary) : Colors.white70),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? _onAccent(scheme.primary) : Colors.white.withOpacity(0.85),
              )),
        ],
      ),
    );
  }
}

/// Full-screen animated backdrop: accent gradient + optional blurred artwork.
class GlassBackdrop extends StatelessWidget {
  final Color accent;
  final Color? mood;
  final ImageProvider? art;
  const GlassBackdrop({super.key, required this.accent, this.mood, this.art});

  @override
  Widget build(BuildContext context) {
    final c = mood ?? accent;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 900),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF0B0B12), c, 0.42)!,
                  const Color(0xFF0B0B12),
                  Color.lerp(const Color(0xFF0B0B12), accent, 0.18)!,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          if (art != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: Opacity(
                key: ValueKey(art),
                opacity: 0.35,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Image(image: art!, fit: BoxFit.cover),
                ),
              ),
            ),
          Positioned(
            top: -120,
            right: -80,
            child: _Blob(color: c.withOpacity(0.35), size: 320),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _Blob(color: accent.withOpacity(0.25), size: 360),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    // A radial gradient looks like a blurred circle and costs nothing to draw.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)], stops: const [0.0, 1.0]),
      ),
    );
  }
}
