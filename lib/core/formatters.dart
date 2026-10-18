String fmtDuration(Duration? d) {
  if (d == null) return '--:--';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

String fmtLong(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '$h hr $m min';
  return '$m min';
}

String plural(int n, String one, [String? many]) {
  if (n == 1) return '1 $one';
  final word = many ?? '${one}s';
  return '$n $word';
}

String decodeHtml(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&#039;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final c = int.tryParse(m.group(1)!);
      return c == null ? m.group(0)! : String.fromCharCode(c);
    });

/// "hindi" -> "Hindi".
String langLabel(String l) => l.isEmpty ? l : l[0].toUpperCase() + l.substring(1);

String greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Late night tunes';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 21) return 'Good evening';
  return 'Good night';
}
