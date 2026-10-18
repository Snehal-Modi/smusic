import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'services/audio_handler.dart';
import 'services/download_service.dart';
import 'services/local_library.dart';
import 'services/lyrics_service.dart';
import 'services/podcast_service.dart';
import 'services/reco_service.dart';
import 'services/storage.dart';
import 'state/collections_state.dart';
import 'state/library_state.dart';
import 'state/mood_state.dart';
import 'state/net_state.dart';
import 'state/online_state.dart';
import 'state/podcast_state.dart';
import 'state/settings_state.dart';
import 'state/taste_state.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = await Store.open();
  final settings = SettingsState(store);
  final library = LocalLibrary();
  final libraryState = LibraryState(library);
  final collections = CollectionsState(store);
  final downloads = DownloadService(store);
  final taste = TasteState(store);
  final podcastState = PodcastState(store);
  final podcastService = PodcastService();
  final net = NetState();

  final handler = await AudioService.init(
    builder: () => SmusicAudioHandler(library: library, settings: settings, store: store),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.smusic.smusic.playback',
      androidNotificationChannelName: 'smusic playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_stat_smusic',
      androidShowNotificationBadge: false,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      preloadArtwork: true,
    ),
  );

  handler.onTrackStarted = (t) {
    collections.pushRecent(t);
    taste.recordListen(t);
  };
  handler.onTrackSkipped = taste.recordSkip;
  handler.recommender = (seed, queue) => RecoService.similarTo(
        seed,
        exclude: queue,
        language: settings.languages.isEmpty ? null : settings.languages.first,
      );
  collections.onLiked = taste.recordLike;
  handler.offlineCopy = downloads.localCopy;
  handler.browse = BrowseDelegate(
    songs: () => libraryState.songs,
    albums: () => libraryState.albums,
    liked: () => collections.liked,
    playlists: () => collections.playlists,
    downloads: () => downloads.downloads,
    recent: () => collections.recent,
  );
  if (settings.resumeOnStart) handler.restore();
  downloads.prune();

  runApp(SmusicApp(
    settings: settings,
    library: library,
    libraryState: libraryState,
    collections: collections,
    downloads: downloads,
    handler: handler,
    taste: taste,
    podcastState: podcastState,
    podcastService: podcastService,
    net: net,
  ));
}

class SmusicApp extends StatelessWidget {
  final SettingsState settings;
  final LocalLibrary library;
  final LibraryState libraryState;
  final CollectionsState collections;
  final DownloadService downloads;
  final SmusicAudioHandler handler;
  final TasteState taste;
  final PodcastState podcastState;
  final PodcastService podcastService;
  final NetState net;

  const SmusicApp({
    super.key,
    required this.settings,
    required this.library,
    required this.libraryState,
    required this.collections,
    required this.downloads,
    required this.handler,
    required this.taste,
    required this.podcastState,
    required this.podcastService,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider<LocalLibrary>.value(value: library),
        ChangeNotifierProvider.value(value: libraryState),
        ChangeNotifierProvider.value(value: collections),
        ChangeNotifierProvider.value(value: downloads),
        Provider<SmusicAudioHandler>.value(value: handler),
        Provider<LyricsService>(create: (_) => LyricsService()),
        ChangeNotifierProvider.value(value: taste),
        ChangeNotifierProvider.value(value: podcastState),
        ChangeNotifierProvider.value(value: net),
        Provider<PodcastService>.value(value: podcastService),
        ChangeNotifierProvider(
          create: (_) => OnlineState(settings: settings, taste: taste, collections: collections, podcasts: podcastService),
        ),
        ChangeNotifierProvider(create: (_) => MoodState(handler, library)),
      ],
      child: Consumer<SettingsState>(
        builder: (c, s, _) => MaterialApp(
          title: 'smusic',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(s.accent),
          // Huge system font sizes break fixed-height rows; keep the scale sane.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AppShell(),
        ),
      ),
    );
  }
}
