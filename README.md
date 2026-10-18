<div align="center">

<img src="docs/icon.png" width="120" alt="smusic minion icon">

# smusic

**A glassy, Spotify-style music player for Android.**
Your own songs, JioSaavn, YouTube, Audius, radio, podcasts and stories, in one app.

[![Download APK](https://img.shields.io/badge/Download-smusic.apk-7C5CFF?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Snehal-Modi/smusic/releases/latest/download/smusic.apk)

[![Latest release](https://img.shields.io/github/v/release/Snehal-Modi/smusic?label=latest&color=1DB954)](https://github.com/Snehal-Modi/smusic/releases/latest)
[![Build](https://github.com/Snehal-Modi/smusic/actions/workflows/build.yml/badge.svg)](https://github.com/Snehal-Modi/smusic/actions/workflows/build.yml)
[![Downloads](https://img.shields.io/github/downloads/Snehal-Modi/smusic/total?color=00C2FF)](https://github.com/Snehal-Modi/smusic/releases)

</div>

## Download

1. On your Android phone, tap **Download smusic.apk** above
   (or open the [Releases page](https://github.com/Snehal-Modi/smusic/releases/latest)).
2. Open the downloaded file. When Android asks, allow **install from unknown sources**.
3. First launch: allow access to music (so your own songs appear) and notifications
   (so the play controls show on the lock screen).

Needs Android 8.0 or newer. New versions install over the old one and keep your
playlists, likes and downloads.

> The download link only works while this repository is **public**.

## What it does

**Music that follows your taste**
- Home learns from what you play: *Made for you* mixes, *Because you listened to...*
  and rows for each language you pick (Hindi, English, Punjabi, Gujarati, Marathi,
  Tamil, Telugu, Kannada, Malayalam, Bengali, Bhojpuri and more)
- Likes teach it more, quick skips teach it what you do not want
- *Keep the music going*: when the queue runs low it adds songs like the one playing
- Top 50 chart and trending songs for every language you choose

**Podcasts and stories**
- Browse the top podcasts in India, search any show, pick a topic (Stories, Bedtime,
  Comedy, True crime, News, Devotional, Motivation, Business, Kids)
- Follow shows, play the latest episode, download episodes for offline

**Works without internet**
- When the connection drops, Home switches by itself to your downloaded songs,
  liked songs and the music on your phone, and switches back when you are online

**The player**
- Local / Online switch at the top of every screen
- Albums, artists, folders, playlists, liked songs, history, downloads
- Queue with drag reorder, shuffle, repeat, play next, 10-second skips
- Resumes the last queue and position when you reopen the app
- Synced lyrics, sleep timer, playback speed, 5-band equalizer, loudness boost
- Lock-screen and notification controls, headphone buttons, Android Auto
- Three streaming qualities, large buffer and stream cache for weak internet
- Frosted-glass look, accent colour of your choice, mood colours from album art

## For the maintainer: publishing a new version

You only ever change **one line**.

1. Edit `pubspec.yaml` and raise the version:
   ```yaml
   version: 1.3.0+4     # name+build number: 1.3.0 is shown, 4 must go up every time
   ```
2. Commit and push to `main`.
3. GitHub Actions builds the APK and creates the release **v1.3.0** by itself,
   with the APK and automatic release notes. Watch it in the **Actions** tab.

The README links never change, because every release also carries a fixed-name
`smusic.apk` and the links point at *latest*. Nothing in this file needs editing
for a new release. Details and troubleshooting are in [docs/RELEASING.md](docs/RELEASING.md).

If you push without raising the version, the existing release for that version is
updated with the new APK instead of a new release being created.

## How the APK gets built

Every push to `main` runs `.github/workflows/build.yml` on GitHub's servers: it
installs Flutter 3.27.1, runs the analyzer, builds a signed release APK and attaches
it to a GitHub Release named after the `version:` line in `pubspec.yaml`.

The first build creates `android/app/smusic.jks` and commits it back so every later
APK has the same signature and installs as an update. **Do not delete it.** (The
keystore and its password are in the repo, so anyone could sign an APK with this
name. For a personal sideloaded app that is acceptable.)

## Build locally (optional)

```bash
flutter pub get
flutter build apk --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`.

## Sources and what may break

| Source | Status | Where |
| --- | --- | --- |
| Songs on phone | stable | MediaStore via `MainActivity.kt` |
| JioSaavn | unofficial | `lib/services/sources/saavn_source.dart` |
| YouTube | unofficial, with fallback servers | `lib/services/sources/youtube_source.dart` |
| Audius | official API | `lib/services/sources/audius_source.dart` |
| Radio | community API | `lib/services/sources/radio_source.dart` |
| Podcasts | Apple directory + RSS | `lib/services/podcast_service.dart` |
| Lyrics | LRCLIB | `lib/services/lyrics_service.dart` |

When an unofficial source stops working, only its one file needs a patch. If a
YouTube or Audius song cannot be opened, smusic tries to play the same song from
JioSaavn instead.

## Project layout

```
lib/
  main.dart                 app start, providers, audio service
  core/                     theme, glass widgets, formatters
  models/                   Track, TrackGroup, Playlist, Podcast
  services/                 audio handler, sources, recommendations, podcasts,
                            lyrics, downloads, storage
  state/                    settings, library, collections, online feed, taste,
                            connectivity, podcasts, mood
  ui/                       shell, pages, now playing, podcasts, sheets, widgets
android/app/src/main/kotlin/com/smusic/smusic/MainActivity.kt   MediaStore bridge
.github/workflows/build.yml                                     APK release build
```
