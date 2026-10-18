import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/audio_handler.dart';
import '../collection_page.dart';
import 'art.dart';
import 'track_tile.dart';

/// Horizontal scroller used for every "row" on Home.
class HorizontalRow extends StatelessWidget {
  final List<Widget> children;
  final double height;
  const HorizontalRow({super.key, required this.children, this.height = 206});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (c, i) => children[i],
      ),
    );
  }
}

/// Square card for a single track (trending rows, recently added...).
class TrackCard extends StatelessWidget {
  final Track track;
  final List<Track> tracks;
  final double size;
  const TrackCard({super.key, required this.track, required this.tracks, this.size = 148});

  @override
  Widget build(BuildContext context) {
    final handler = context.read<SmusicAudioHandler>();
    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => handler.playTrackIn(track, tracks),
        onLongPress: () => showTrackMenu(context, track, contextTracks: tracks),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: ArtImage(track: track, size: size, radius: 18),
            ),
            const SizedBox(height: 8),
            Text(track.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            Text(track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Card for an album / artist / folder.
class GroupCard extends StatelessWidget {
  final TrackGroup group;
  final CollectionKind kind;
  final double size;
  const GroupCard({super.key, required this.group, required this.kind, this.size = 148});

  @override
  Widget build(BuildContext context) {
    final circle = kind == CollectionKind.artist;
    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(group: group, kind: kind))),
        child: Column(
          crossAxisAlignment: circle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(circle ? size / 2 : 18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: kind == CollectionKind.folder
                  ? _FolderArt(group: group, size: size)
                  : ArtImage(track: group.cover, size: size, radius: 18, circle: circle),
            ),
            const SizedBox(height: 8),
            Text(group.title,
                maxLines: 1,
                textAlign: circle ? TextAlign.center : TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            Text(group.subtitle,
                maxLines: 1,
                textAlign: circle ? TextAlign.center : TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _FolderArt extends StatelessWidget {
  final TrackGroup group;
  final double size;
  const _FolderArt({required this.group, required this.size});

  @override
  Widget build(BuildContext context) {
    final covers = group.tracks.take(4).toList();
    final cell = size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: size,
        height: size,
        child: covers.length < 4
            ? ArtImage(track: covers.isEmpty ? null : covers.first, size: size, radius: 0)
            : Wrap(children: covers.map((t) => ArtImage(track: t, size: cell, radius: 0)).toList()),
      ),
    );
  }
}

/// Responsive grid of GroupCards used by Library tabs.
class GroupGrid extends StatelessWidget {
  final List<TrackGroup> groups;
  final CollectionKind kind;
  final EdgeInsets padding;
  const GroupGrid({super.key, required this.groups, required this.kind, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 120)});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, box) {
      final cols = (box.maxWidth / 170).floor().clamp(2, 8).toInt();
      final w = (box.maxWidth - padding.horizontal - (cols - 1) * 14) / cols;
      return GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: w / (w + 46),
        ),
        itemCount: groups.length,
        itemBuilder: (c, i) => GroupCard(group: groups[i], kind: kind, size: w),
      );
    });
  }
}
