import 'package:audio_service/audio_service.dart';

enum TrackSource { local, download, youtube, saavn, audius, radio }

TrackSource trackSourceFrom(String? s) {
  for (final v in TrackSource.values) {
    if (v.name == s) return v;
  }
  return TrackSource.local;
}

String sourceLabel(TrackSource s) {
  switch (s) {
    case TrackSource.local:
      return 'On device';
    case TrackSource.download:
      return 'Downloaded';
    case TrackSource.youtube:
      return 'YouTube';
    case TrackSource.saavn:
      return 'JioSaavn';
    case TrackSource.audius:
      return 'Audius';
    case TrackSource.radio:
      return 'Radio';
  }
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final TrackSource source;

  /// Directly playable uri (content://, file://, http stream for radio).
  /// Null for youtube/saavn/audius until resolved.
  final String? uri;

  /// Network artwork url (online sources, downloads).
  final String? artUrl;

  /// Local MediaStore ids.
  final int? localId;
  final int? albumId;
  final String? path;
  final int? dateAdded;
  final int? trackNo;
  final int? year;

  /// Source specific key: youtube videoId, saavn encrypted_media_url, audius id.
  final String? extra;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.source,
    this.duration,
    this.uri,
    this.artUrl,
    this.localId,
    this.albumId,
    this.path,
    this.dateAdded,
    this.trackNo,
    this.year,
    this.extra,
  });

  bool get isLive => source == TrackSource.radio;
  bool get isLocal => source == TrackSource.local || source == TrackSource.download;
  bool get needsResolve =>
      source == TrackSource.youtube || source == TrackSource.saavn || source == TrackSource.audius;

  String get folder {
    final p = path;
    if (p == null || p.isEmpty) return '';
    final i = p.lastIndexOf('/');
    return i <= 0 ? '/' : p.substring(0, i);
  }

  String get folderName {
    final f = folder;
    final i = f.lastIndexOf('/');
    return i < 0 ? f : f.substring(i + 1);
  }

  Track copyWith({String? uri, String? artUrl, Duration? duration, TrackSource? source, String? path}) {
    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      source: source ?? this.source,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      artUrl: artUrl ?? this.artUrl,
      localId: localId,
      albumId: albumId,
      path: path ?? this.path,
      dateAdded: dateAdded,
      trackNo: trackNo,
      year: year,
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'duration': duration?.inMilliseconds,
        'source': source.name,
        'uri': uri,
        'artUrl': artUrl,
        'localId': localId,
        'albumId': albumId,
        'path': path,
        'dateAdded': dateAdded,
        'trackNo': trackNo,
        'year': year,
        'extra': extra,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        artist: (j['artist'] ?? '') as String,
        album: (j['album'] ?? '') as String,
        duration: j['duration'] == null ? null : Duration(milliseconds: (j['duration'] as num).toInt()),
        source: trackSourceFrom(j['source'] as String?),
        uri: j['uri'] as String?,
        artUrl: j['artUrl'] as String?,
        localId: (j['localId'] as num?)?.toInt(),
        albumId: (j['albumId'] as num?)?.toInt(),
        path: j['path'] as String?,
        dateAdded: (j['dateAdded'] as num?)?.toInt(),
        trackNo: (j['trackNo'] as num?)?.toInt(),
        year: (j['year'] as num?)?.toInt(),
        extra: j['extra'] as String?,
      );

  factory Track.fromMediaStore(Map<dynamic, dynamic> m) {
    final id = (m['id'] as num).toInt();
    String artist = (m['artist'] ?? '') as String;
    if (artist == '<unknown>' || artist.isEmpty) artist = 'Unknown artist';
    String album = (m['album'] ?? '') as String;
    if (album.isEmpty) album = 'Unknown album';
    String title = (m['title'] ?? '') as String;
    final path = (m['path'] ?? '') as String;
    if (title.isEmpty) {
      title = path.split('/').last;
    }
    return Track(
      id: 'local:$id',
      title: title,
      artist: artist,
      album: album,
      source: TrackSource.local,
      duration: Duration(milliseconds: (m['duration'] as num).toInt()),
      uri: m['uri'] as String?,
      localId: id,
      albumId: (m['albumId'] as num?)?.toInt(),
      path: path,
      dateAdded: (m['dateAdded'] as num?)?.toInt(),
      trackNo: (m['track'] as num?)?.toInt(),
      year: (m['year'] as num?)?.toInt(),
    );
  }

  MediaItem toMediaItem({Uri? artUri}) => MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration: isLive ? null : duration,
        artUri: artUri ?? (artUrl != null ? Uri.tryParse(artUrl!) : null),
        playable: true,
        extras: {'source': source.name},
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class TrackGroup {
  final String key;
  final String title;
  final String subtitle;
  final List<Track> tracks;
  const TrackGroup({required this.key, required this.title, required this.subtitle, required this.tracks});

  Track? get cover => tracks.isEmpty ? null : tracks.first;
  Duration get totalDuration => tracks.fold(Duration.zero, (a, t) => a + (t.duration ?? Duration.zero));
}

class Playlist {
  final String id;
  String name;
  final List<Track> tracks;
  final int createdAt;
  Playlist({required this.id, required this.name, required this.tracks, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: (j['name'] ?? 'Playlist') as String,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        tracks: ((j['tracks'] as List?) ?? const [])
            .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
