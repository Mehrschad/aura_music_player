import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../domain/models/song.dart';
import '../../../domain/taste/smart_collection.dart';
import '../artwork/aura_artwork.dart';

/// A generated cover that stays *unique per playlist* and clearly reads as a
/// collection rather than a single album:
///   • the top ~62% is a **2×2 mosaic** of up-to-four covers from *distinct
///     albums* in the list. Drawing from different albums (not just the first
///     track) means two playlists with overlapping tracks no longer collide,
///     and a four-up grid never looks like one album. When more than four
///     distinct albums exist the four shown are chosen by a per-cover seed, so
///     even similar playlists differ.
///   • the bottom ~38% is a solid, seed-tinted dark panel with the name
///     (monospace), a count, and a kind glyph — the identity.
///
/// All deterministic and cheap (no async colour extraction).
class CollectionCover extends StatelessWidget {
  CollectionCover.collection(
    SmartCollection collection, {
    super.key,
    this.size,
    this.radius = RadiusTokens.lg,
  })  : title = collection.title,
        count = collection.songs.length,
        colorSeed = collection.id,
        icon = _glyphForKind(collection.kind),
        songs = collection.songs;

  const CollectionCover.label({
    super.key,
    required this.title,
    required this.icon,
    required this.colorSeed,
    this.count,
    this.songs = const [],
    this.size,
    this.radius = RadiusTokens.lg,
  });

  final String title;

  /// Track count shown as an eyebrow; null hides it.
  final int? count;
  final IconData icon;

  /// Deterministic colour key (collection id, playlist id…).
  final String colorSeed;

  /// Songs to draw mosaic covers from.
  final List<Song> songs;

  /// Square edge length; null fills the parent.
  final double? size;
  final double radius;

  static const String _mono = 'monospace';

  static const List<Color> _palette = [
    Color(0xFF1F6F6A), // deep teal
    Color(0xFF4E4A85), // muted indigo
    Color(0xFF7A3B53), // plum
    Color(0xFF2E5A88), // slate blue
    Color(0xFF6B5235), // warm bronze
    Color(0xFF3E6B43), // forest
  ];

  static int _hash(String s, [int seed = 0]) {
    var h = 0x811c9dc5 ^ seed;
    for (final c in s.codeUnits) {
      h = (h ^ c) & 0xFFFFFFFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  Color get _color => _palette[_hash(colorSeed) % _palette.length];

  static IconData _glyphForKind(SmartCollectionKind kind) => switch (kind) {
        SmartCollectionKind.forYou => Icons.auto_awesome,
        SmartCollectionKind.mix => Icons.equalizer_rounded,
        SmartCollectionKind.mood => Icons.waves_rounded,
        SmartCollectionKind.heavyRotation => Icons.local_fire_department_rounded,
        SmartCollectionKind.hiddenGems => Icons.diamond_outlined,
        SmartCollectionKind.rediscover => Icons.history_rounded,
        SmartCollectionKind.artist => Icons.person_rounded,
      };

  /// Up to four distinct-album representative songs for the mosaic, selected by
  /// a per-cover seed so different lists differ even when they overlap.
  List<Song> _mosaic() {
    final seenAlbums = <String>{};
    final distinct = <Song>[];
    for (final s in songs) {
      if (seenAlbums.add(s.albumId)) distinct.add(s);
    }
    if (distinct.length <= 4) return distinct;
    final seed = _hash(colorSeed);
    distinct.sort(
        (a, b) => _hash(a.albumId, seed).compareTo(_hash(b.albumId, seed)));
    return distinct.take(4).toList();
  }

  Widget _tile(Song s) => AuraArtwork(
        seed: s.artworkSeed,
        fill: true,
        borderRadius: BorderRadius.zero,
        hasArtwork: s.hasArtwork,
        artworkId: int.tryParse(s.id),
      );

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final panelColor =
        Color.alphaBlend(color.withOpacity(0.32), const Color(0xFF0D0D0F));

    final mosaic = _mosaic();
    final Widget top;
    if (mosaic.isEmpty) {
      top = ColoredBox(
        color: color,
        child: Center(
          child: Icon(icon, color: Colors.white.withOpacity(0.30), size: 40),
        ),
      );
    } else if (mosaic.length == 1) {
      top = _tile(mosaic.first);
    } else {
      // 2×2 grid; with 2–3 distinct covers the cells cycle to fill.
      top = Column(
        children: [
          for (var row = 0; row < 2; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 2; col++)
                    Expanded(child: _tile(mosaic[(row * 2 + col) % mosaic.length])),
                ],
              ),
            ),
        ],
      );
    }

    final panel = ColoredBox(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: Colors.white.withOpacity(0.55)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    count != null ? '$count TRACKS' : 'PLAYLIST',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _mono,
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: _mono,
                color: Colors.white,
                fontSize: 14,
                height: 1.12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );

    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 62, child: top),
          Expanded(flex: 38, child: panel),
        ],
      ),
    );

    if (size == null) return cover;
    return SizedBox(width: size, height: size, child: cover);
  }
}
