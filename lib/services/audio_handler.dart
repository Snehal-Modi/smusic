import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
import '../state/settings_state.dart';
import 'local_library.dart';
import 'sources/music_source.dart';

enum RepeatMode { off, all, one }

/// Lets the handler browse the library for Android Auto without depending on UI state.
class BrowseDelegate {
  final List<Track> Function() songs;
  final List<TrackGroup> Function() albums;
  final List<Track> Function() liked;
  final List<Playlist> Function() playlists;
  final List<Track> Function() downloads;
  final List<Track> Function() recent;
  BrowseDelegate({
    required this.songs,
    required this.albums,
    required this.liked,
    required this.playlists,
    required this.downloads,
    required this.recent,
  });
}

/// The one player for the whole app: queue, shuffle, repeat, resolving online
/// streams, caching, sleep timer, lock-screen controls and Android Auto.
class SmusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final LocalLibrary library;
  final SettingsState settings;

  late final AudioPlayer player;
  late final AndroidEqualizer equalizer;
  late final AndroidLoudnessEnhancer loudness;

  final ValueNotifier<Track?> current = ValueNotifier(null);
  final ValueNotifier<List<Track>> queueTracks = ValueNotifier(const []);
  final ValueNotifier<int> index = ValueNotifier(0);
  final ValueNotifier<bool> shuffle = ValueNotifier(false);
  final ValueNotifier<RepeatMode> repeat = ValueNotifier(RepeatMode.off);
  final ValueNotifier<Duration?> sleepLeft = ValueNotifier(null);
  final ValueNotifier<bool> sleepAtEnd = ValueNotifier(false);
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  final ValueNotifier<bool> resolving = ValueNotifier(false);

  void Function(Track track)? onTrackStarted;
  BrowseDelegate? browse;

  List<Track> _queue = [];
  List<Track>? _unshuffled;
  final Map<String, ResolvedStream> _resolved = {};
  int _loadToken = 0;
  int _failures = 0;
  bool _completing = false;
  Timer? _sleepTimer;

  SmusicAudioHandler({required this.library, required this.settings}) {
    equalizer = AndroidEqualizer();
    loudness = AndroidLoudnessEnhancer();
    final big = settings.bigBuffer;
    player = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [loudness, equalizer]),
      audioLoadConfiguration: AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: big ? 60 : 25),
          maxBufferDuration: Duration(seconds: big ? 240 : 120),
          bufferForPlaybackDuration: const Duration(milliseconds: 1200),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: big ? 8 : 3),
          prioritizeTimeOverSizeThresholds: true,
        ),
      ),
    );
    _init();
  }

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.becomingNoisyEventStream.listen((_) => pause());
    } catch (_) {}

    player.playbackEventStream.listen(_broadcast, onError: (Object e, StackTrace st) {
      lastError.value = 'Playback error';
    });
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _onComplete();
    });
    player.durationStream.listen((d) {
      final cur = current.value;
      final mi = mediaItem.value;
      if (d != null && cur != null && mi != null && !cur.isLive && mi.duration != d) {
        mediaItem.add(mi.copyWith(duration: d));
      }
    });
  }

  // ---------------------------------------------------------------- state

  void _broadcast(PlaybackEvent event) {
    final playing = player.playing;
    final live = current.value?.isLive ?? false;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: live
          ? const {}
          : const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: index.value,
      repeatMode: repeat.value == RepeatMode.off
          ? AudioServiceRepeatMode.none
          : repeat.value == RepeatMode.one
              ? AudioServiceRepeatMode.one
              : AudioServiceRepeatMode.all,
      shuffleMode: shuffle.value ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }

  void _syncQueue() {
    queueTracks.value = List.unmodifiable(_queue);
    queue.add(_queue.map((t) => t.toMediaItem()).toList());
  }

  bool get hasQueue => _queue.isNotEmpty;
  bool get hasNext => _queue.length > 1;
  bool get hasPrevious => _queue.length > 1;
  Track? get nextTrack {
    if (_queue.isEmpty) return null;
    final i = index.value + 1;
    if (i < _queue.length) return _queue[i];
    return repeat.value == RepeatMode.all ? _queue.first : null;
  }

  // ---------------------------------------------------------------- loading

  Future<ResolvedStream?> _resolve(Track t) async {
    final cached = _resolved[t.id];
    if (cached != null && cached.fresh) return cached;
    final rs = await Sources.resolve(t, lowQuality: settings.lowQuality);
    if (rs != null && t.needsResolve) _resolved[t.id] = rs;
    return rs;
  }

  Future<void> _load(int i, {bool autoplay = true, Duration? startAt}) async {
    if (i < 0 || i >= _queue.length) return;
    final token = ++_loadToken;
    index.value = i;
    final t = _queue[i];
    current.value = t;
    lastError.value = null;
    resolving.value = true;

    Uri? artUri;
    if (t.source == TrackSource.local) {
      try {
        artUri = await library.artFileUri(t);
      } catch (_) {}
      if (token != _loadToken) return;
    }
    mediaItem.add(t.toMediaItem(artUri: artUri));
    _broadcast(player.playbackEvent);

    try {
      final rs = await _resolve(t);
      if (token != _loadToken) return;
      if (rs == null) throw Exception('no stream');

      final useCache = settings.cacheStreams && rs.cacheable && !t.isLocal;
      AudioSource src = useCache
          ? LockCachingAudioSource(rs.uri, headers: rs.headers, tag: t.id)
          : AudioSource.uri(rs.uri, headers: rs.headers, tag: t.id);
      try {
        await player.setAudioSource(src, initialPosition: startAt, preload: true);
      } catch (e) {
        if (token != _loadToken) return;
        if (!useCache) rethrow;
        // Cache proxy did not like this server: play it straight.
        src = AudioSource.uri(rs.uri, headers: rs.headers, tag: t.id);
        await player.setAudioSource(src, initialPosition: startAt, preload: true);
      }
      if (token != _loadToken) return;
      resolving.value = false;
      _failures = 0;
      if (autoplay) player.play();
      onTrackStarted?.call(t);
      _prefetchNext();
    } catch (e) {
      if (token != _loadToken) return;
      resolving.value = false;
      _resolved.remove(t.id);
      lastError.value = 'Could not play "${t.title}"';
      _failures++;
      if (autoplay && _failures < 3 && _queue.length > 1) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (token != _loadToken) return;
        await _next(auto: true);
      }
    }
  }

  void _prefetchNext() {
    final n = nextTrack;
    if (n == null || !n.needsResolve) return;
    final cached = _resolved[n.id];
    if (cached != null && cached.fresh) return;
    Sources.resolve(n, lowQuality: settings.lowQuality).then((rs) {
      if (rs != null) _resolved[n.id] = rs;
    }).catchError((_) {});
  }

  Future<void> _onComplete() async {
    if (_completing) return;
    _completing = true;
    try {
      if (sleepAtEnd.value) {
        sleepAtEnd.value = false;
        await player.pause();
        await player.seek(Duration.zero);
        return;
      }
      if (repeat.value == RepeatMode.one) {
        await player.seek(Duration.zero);
        player.play();
        return;
      }
      await _next(auto: true);
    } finally {
      _completing = false;
    }
  }

  Future<void> _next({bool auto = false}) async {
    if (_queue.isEmpty) return;
    var i = index.value + 1;
    if (i >= _queue.length) {
      if (repeat.value == RepeatMode.all || !auto) {
        i = 0;
      } else {
        await player.pause();
        await player.seek(Duration.zero);
        return;
      }
    }
    await _load(i);
  }

  // ---------------------------------------------------------------- public queue API

  Future<void> playAll(List<Track> tracks, {int startIndex = 0, bool shuffleMode = false}) async {
    if (tracks.isEmpty) return;
    final start = tracks[startIndex.clamp(0, tracks.length - 1).toInt()];
    _unshuffled = null;
    if (shuffleMode) {
      final rest = List.of(tracks)..remove(start);
      rest.shuffle(Random());
      _queue = [start, ...rest];
      _unshuffled = List.of(tracks);
      shuffle.value = true;
      _syncQueue();
      await _load(0);
    } else {
      _queue = List.of(tracks);
      shuffle.value = false;
      _syncQueue();
      await _load(_queue.indexOf(start));
    }
  }

  Future<void> playTrackIn(Track t, List<Track> context) async {
    final list = context.contains(t) ? context : [t, ...context];
    await playAll(list, startIndex: list.indexOf(t));
  }

  Future<void> enqueue(Track t) async {
    if (_queue.isEmpty) {
      await playAll([t]);
      return;
    }
    _queue.add(t);
    _unshuffled?.add(t);
    _syncQueue();
    _prefetchNext();
  }

  Future<void> enqueueAll(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    if (_queue.isEmpty) {
      await playAll(tracks);
      return;
    }
    _queue.addAll(tracks);
    _unshuffled?.addAll(tracks);
    _syncQueue();
  }

  Future<void> playNextTrack(Track t) async {
    if (_queue.isEmpty) {
      await playAll([t]);
      return;
    }
    _queue.remove(t);
    final cur = current.value;
    final at = cur == null ? 0 : _queue.indexOf(cur) + 1;
    _queue.insert(at, t);
    index.value = cur == null ? 0 : _queue.indexOf(cur);
    _unshuffled?.add(t);
    _syncQueue();
    _prefetchNext();
  }

  Future<void> removeAt(int i) async {
    if (i < 0 || i >= _queue.length) return;
    final removed = _queue.removeAt(i);
    _unshuffled?.remove(removed);
    if (_queue.isEmpty) {
      await stop();
      current.value = null;
      index.value = 0;
      _syncQueue();
      return;
    }
    if (i == index.value) {
      _syncQueue();
      await _load(min(i, _queue.length - 1), autoplay: player.playing);
      return;
    }
    if (i < index.value) index.value = index.value - 1;
    _syncQueue();
    _broadcast(player.playbackEvent);
  }

  void move(int from, int to) {
    if (from < 0 || from >= _queue.length) return;
    final cur = current.value;
    final t = _queue.removeAt(from);
    if (to > from) to -= 1;
    _queue.insert(to.clamp(0, _queue.length).toInt(), t);
    if (cur != null) index.value = max(0, _queue.indexOf(cur));
    _syncQueue();
    _broadcast(player.playbackEvent);
    _prefetchNext();
  }

  Future<void> clearQueue() async {
    _queue = [];
    _unshuffled = null;
    await stop();
    current.value = null;
    index.value = 0;
    _syncQueue();
  }

  Future<void> toggleShuffle() async {
    final cur = current.value;
    if (!shuffle.value) {
      _unshuffled = List.of(_queue);
      final rest = List.of(_queue);
      if (cur != null) rest.remove(cur);
      rest.shuffle(Random());
      _queue = cur == null ? rest : [cur, ...rest];
      index.value = 0;
      shuffle.value = true;
    } else {
      final base = _unshuffled ?? List.of(_queue);
      for (final t in _queue) {
        if (!base.contains(t)) base.add(t);
      }
      base.removeWhere((t) => !_queue.contains(t));
      _queue = base;
      _unshuffled = null;
      index.value = cur == null ? 0 : max(0, _queue.indexOf(cur));
      shuffle.value = false;
    }
    _syncQueue();
    _broadcast(player.playbackEvent);
    _prefetchNext();
  }

  Future<void> cycleRepeat() async {
    switch (repeat.value) {
      case RepeatMode.off:
        repeat.value = RepeatMode.all;
        break;
      case RepeatMode.all:
        repeat.value = RepeatMode.one;
        break;
      case RepeatMode.one:
        repeat.value = RepeatMode.off;
        break;
    }
    _broadcast(player.playbackEvent);
    _prefetchNext();
  }

  Future<void> seekBy(Duration delta) async {
    if (current.value?.isLive ?? false) return;
    final d = player.duration;
    var p = player.position + delta;
    if (p < Duration.zero) p = Duration.zero;
    if (d != null && p > d) p = d;
    await player.seek(p);
  }

  Future<void> togglePlay() async {
    if (player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  // ---------------------------------------------------------------- sleep timer

  void setSleep(Duration? d) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepLeft.value = d;
    if (d == null) return;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final left = sleepLeft.value;
      if (left == null) return;
      final n = left - const Duration(seconds: 1);
      if (n <= Duration.zero) {
        _sleepTimer?.cancel();
        _sleepTimer = null;
        sleepLeft.value = null;
        await pause();
      } else {
        sleepLeft.value = n;
      }
    });
  }

  void setSleepAtEnd(bool v) => sleepAtEnd.value = v;

  // ---------------------------------------------------------------- audio_service overrides

  @override
  Future<void> play() async {
    if (_queue.isEmpty) return;
    if (player.processingState == ProcessingState.idle) {
      await _load(index.value);
      return;
    }
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    await player.play();
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => _next();

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (player.position > const Duration(seconds: 3) || _queue.length == 1) {
      await player.seek(Duration.zero);
      return;
    }
    var i = index.value - 1;
    if (i < 0) i = _queue.length - 1;
    await _load(i);
  }

  @override
  Future<void> skipToQueueItem(int i) => _load(i);

  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    repeat.value = repeatMode == AudioServiceRepeatMode.none
        ? RepeatMode.off
        : repeatMode == AudioServiceRepeatMode.one
            ? RepeatMode.one
            : RepeatMode.all;
    _broadcast(player.playbackEvent);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final want = shuffleMode != AudioServiceShuffleMode.none;
    if (want != shuffle.value) await toggleShuffle();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final t = _findTrack(mediaItem.id);
    if (t != null) await enqueue(t);
  }

  @override
  Future<void> removeQueueItemAt(int i) => removeAt(i);

  // ---------------------------------------------------------------- Android Auto browsing

  static const _rootSongs = 'root:songs';
  static const _rootAlbums = 'root:albums';
  static const _rootLiked = 'root:liked';
  static const _rootPlaylists = 'root:playlists';
  static const _rootDownloads = 'root:downloads';
  static const _rootRecent = 'root:recent';

  List<Track> _tracksFor(String parent) {
    final b = browse;
    if (b == null) return const [];
    if (parent == _rootSongs) return b.songs();
    if (parent == _rootLiked) return b.liked();
    if (parent == _rootDownloads) return b.downloads();
    if (parent == _rootRecent || parent == AudioService.recentRootId) return b.recent();
    if (parent.startsWith('album:')) {
      final key = parent.substring(6);
      for (final g in b.albums()) {
        if (g.key == key) return g.tracks;
      }
    }
    if (parent.startsWith('pl:')) {
      final id = parent.substring(3);
      for (final p in b.playlists()) {
        if (p.id == id) return p.tracks;
      }
    }
    return const [];
  }

  List<MediaItem> _items(List<Track> tracks, String parent) =>
      tracks.map((t) => t.toMediaItem().copyWith(id: '$parent|${t.id}')).toList();

  Track? _findTrack(String id) {
    for (final t in _queue) {
      if (t.id == id) return t;
    }
    final b = browse;
    if (b == null) return null;
    for (final list in [b.songs(), b.liked(), b.downloads(), b.recent()]) {
      for (final t in list) {
        if (t.id == id) return t;
      }
    }
    return null;
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    if (parentMediaId == AudioService.browsableRootId) {
      return const [
        MediaItem(id: _rootSongs, title: 'Songs', playable: false),
        MediaItem(id: _rootAlbums, title: 'Albums', playable: false),
        MediaItem(id: _rootLiked, title: 'Liked songs', playable: false),
        MediaItem(id: _rootPlaylists, title: 'Playlists', playable: false),
        MediaItem(id: _rootDownloads, title: 'Downloads', playable: false),
        MediaItem(id: _rootRecent, title: 'Recently played', playable: false),
      ];
    }
    final b = browse;
    if (b == null) return const [];
    if (parentMediaId == _rootAlbums) {
      return b
          .albums()
          .map((g) => MediaItem(id: 'album:${g.key}', title: g.title, artist: g.subtitle, playable: false))
          .toList();
    }
    if (parentMediaId == _rootPlaylists) {
      return b.playlists().map((p) => MediaItem(id: 'pl:${p.id}', title: p.name, playable: false)).toList();
    }
    return _items(_tracksFor(parentMediaId), parentMediaId);
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final bar = mediaId.indexOf('|');
    if (bar > 0) {
      final parent = mediaId.substring(0, bar);
      final id = mediaId.substring(bar + 1);
      final list = _tracksFor(parent);
      final t = list.where((x) => x.id == id).toList();
      if (t.isNotEmpty) {
        await playTrackIn(t.first, list);
        return;
      }
    }
    final t = _findTrack(mediaId);
    if (t != null) await playTrackIn(t, [t]);
  }

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    final b = browse;
    final q = query.toLowerCase();
    List<Track> hits = const [];
    if (b != null) {
      hits = b
          .songs()
          .where((t) => t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q))
          .toList();
    }
    if (hits.isEmpty) {
      try {
        final r = await Sources.saavn.search(query, limit: 10);
        hits = r;
      } catch (_) {}
    }
    if (hits.isNotEmpty) await playAll(hits);
  }

  @override
  Future<void> onTaskRemoved() async {
    if (!player.playing) await stop();
  }
}
