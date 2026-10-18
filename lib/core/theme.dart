import 'package:flutter/material.dart';

const kBg = Color(0xFF0B0B12);
const kSurface = Color(0xFF141420);

/// Preset accent swatches shown in Settings. Users can also pick any hue.
const List<Color> kAccentPresets = [
  Color(0xFF7C5CFF), // violet (default)
  Color(0xFF1DB954), // spotify green
  Color(0xFFFF3D71), // pink
  Color(0xFFFF8A3D), // amber
  Color(0xFF00C2FF), // sky
  Color(0xFF3DFFB1), // mint
  Color(0xFFFFD53D), // gold
  Color(0xFFFF5252), // red
  Color(0xFFE0E0FF), // ice
];

ThemeData buildTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: accent,
    secondary: accent,
    surface: kSurface,
    onSurface: Colors.white,
  );

  const textColor = Colors.white;
  final text = ThemeData.dark().textTheme.apply(bodyColor: textColor, displayColor: textColor);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.86)),
      bodySmall: text.bodySmall?.copyWith(color: Colors.white.withOpacity(0.6)),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: accent,
      inactiveTrackColor: Colors.white.withOpacity(0.18),
      thumbColor: Colors.white,
      overlayColor: accent.withOpacity(0.2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF181826),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF22223A),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white70, textColor: Colors.white),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withOpacity(0.5),
      indicatorColor: accent,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white70),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : Colors.white.withOpacity(0.15)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF1C1C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(color: Colors.white),
    ),
    dividerColor: Colors.white.withOpacity(0.08),
    splashFactory: InkSparkle.splashFactory,
  );
}
