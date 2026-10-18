import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Is there a working internet connection right now? Checked every few seconds
/// and whenever the app comes back to the foreground, so Home can switch to the
/// offline view (downloaded songs first) on its own and back again.
class NetState extends ChangeNotifier with WidgetsBindingObserver {
  bool online = true;
  bool _checking = false;
  Timer? _timer;

  NetState() {
    WidgetsBinding.instance.addObserver(this);
    check();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => check());
  }

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    var ok = false;
    for (final host in const ['www.google.com', 'cloudflare.com']) {
      try {
        final r = await InternetAddress.lookup(host).timeout(const Duration(seconds: 4));
        if (r.isNotEmpty && r.first.rawAddress.isNotEmpty) {
          ok = true;
          break;
        }
      } catch (_) {}
    }
    _checking = false;
    if (ok != online) {
      online = ok;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
