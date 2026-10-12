# smusic

A glassy, Spotify-style music player for Android. Plays the songs on your phone
and streams from JioSaavn, YouTube, Audius and 30,000 internet radio stations,
with one switch between **Local** and **Online**.

Not on any app store. Download the APK from the **Releases** page of this repo.

## Features

- Local / Online switch at the top of every screen
- Albums, artists, folders, playlists, liked songs, history, downloads
- Queue with drag reorder, shuffle, repeat one / all, play next, 10-second skips
- Synced lyrics that scroll with the song (LRCLIB)
- Lock-screen and notification controls, headphone buttons, Android Auto browsing
- Download online songs for offline play
- Smart buffering, data-saver quality and stream cache for weak internet
- Sleep timer, playback speed, 5-band equalizer and loudness boost
- Frosted-glass UI, accent colour of your choice, mood colours from album art
- Phone, tablet and landscape layouts

## Install on a phone

1. Open the Releases page of this repo on your phone.
2. Download `smusic-vX.Y.Z.apk`.
3. Open it, allow "install from unknown sources" when asked.
4. First launch: allow access to music files so your songs appear.

Requires Android 8.0 or newer.

## How the APK gets built

Every push to `main` runs `.github/workflows/build.yml` on GitHub's servers:
it installs Flutter, builds a signed release APK and attaches it to a GitHub
Release named after the `version:` line in `pubspec.yaml`. Bump that version
before pushing to publish a new release.

The first build creates `android/app/smusic.jks` and commits it back so every
later APK has the same signature and installs as an update. Do not delete it.

## Build locally (optional)

```bash
flutter create --platforms=android --org com.smusic --project-name smusic .
flutter pub get
flutter build apk --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`.

## Sources and what may break

| Source | Status | Notes |
| --- | --- | --- |
| Songs on phone | stable | MediaStore via `MainActivity.kt` |
| JioSaavn | unofficial | `lib/services/sources/saavn_source.dart` |
| YouTube | unofficial | `lib/services/sources/youtube_source.dart` (youtube_explode_dart) |
| Audius | official API | `lib/services/sources/audius_source.dart` |
| Radio | community API | `lib/services/sources/radio_source.dart` |
| Lyrics | LRCLIB | `lib/services/lyrics_service.dart` |

When an unofficial source stops working, only its one file needs a patch.

## Project layout

```
lib/
  main.dart                 app start, providers, audio service
  core/                     theme, glass widgets, formatters
  models/track.dart         Track, TrackGroup, Playlist
  services/                 audio handler, sources, lyrics, downloads, storage
  state/                    settings, library, collections, online, mood
  ui/                       shell, pages, now playing, sheets, widgets
android/app/src/main/kotlin/com/smusic/smusic/MainActivity.kt   MediaStore bridge
.github/workflows/build.yml                                     APK release build
```
