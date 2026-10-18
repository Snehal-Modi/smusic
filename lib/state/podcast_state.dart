import 'package:flutter/foundation.dart';

import '../models/podcast.dart';
import '../services/storage.dart';

/// Shows the listener follows. Kept on the phone.
class PodcastState extends ChangeNotifier {
  final Store _store;
  late List<Podcast> followed;

  PodcastState(this._store) {
    followed = _store
        .getJsonList('followedPodcasts')
        .map((e) => Podcast.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  bool isFollowed(Podcast p) => followed.any((x) => x.id == p.id);

  void toggle(Podcast p) {
    if (isFollowed(p)) {
      followed.removeWhere((x) => x.id == p.id);
    } else {
      followed.insert(0, p);
    }
    _store.setJsonList('followedPodcasts', followed.map((e) => e.toJson()).toList());
    notifyListeners();
  }
}
