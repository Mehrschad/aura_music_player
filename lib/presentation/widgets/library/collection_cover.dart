import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../domain/taste/smart_collection.dart';
import '../artwork/aura_artwork.dart';

/// A modern generated cover with a **hybrid** layout: the top ~60% shows the
/// real representative artwork, the bottom ~40% is a solid, deterministic
/// colour panel carrying the name (monospace), a track count, and a kind glyph.
/// Real art for life + colour, a type panel for legibility and identity. No
/// async colour extraction (kept cheap so rails stay smooth).
///
/// When no artwork is available it degrades to a full solid block with the
/// glyph — the previous text-cover look.
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
        artSeed =
            collection.songs.isEmpty ? null : collection.songs.first.artworkSeed,
        hasArtwork =
            collection.songs.isNotEmpty && collection.songs.first.hasArtwork,
        artworkId = collection.songs.isEmpty
            ? null
            : int.tryParse(collection.songs.first.id);

  const CollectionCover.label({
    super.key,
    required this.title,
    required this.icon,
    required this.colorSeed,
    this.count,
    this.artSeed,
    this.hasArtwork = false,
    this.artworkId,
    this.size,
    this.radius = RadiusTokens.lg,
  });

  final String title;

  /// Track count shown as an eyebrow; null hides it.
  final int? count;
  final IconData icon;

  /// Deterministic colour key (collection id, playlist id…).
  final String colorSeed;

  /// Representative artwork for the top portion (null → solid fallback).
  final String? artSeed;
  final bool hasArtwork;
  final int? artworkId;

  /// Square edge length; null fills the parent.
  final double? size;
  final double radius;

  static const String _mono = 'monospace';

  /// Deep, rich-but-restrained tones that all carry white type well.
  static const List<Color> _palette = [
    Color(0xFF1F6F6A), // deep teal (kin to the brand accent)
    Color(0xFF4E4A85), // muted indigo
    Color(0xFF7A3B53), // plum
    Color(0xFF2E5A88), // slate blue
    Color(0xFF6B5235), // warm bronze
    Color(0xFF3E6B43), // forest
  ];

  Color get _color {
    var h = 0;
    for (final c in colorSeed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  static IconData _glyphForKind(SmartCollectionKind kind) => switch (kind) {
        SmartCollectionKind.forYou => Icons.auto_awesome,
        SmartCollectionKind.mix => Icons.equalizer_rounded,
        SmartCollectionKind.mood => Icons.waves_rounded,
        SmartCollectionKind.heavyRotation => Icons.local_fire_department_rounded,
        SmartCollectionKind.hiddenGems => Icons.diamond_outlined,
        SmartCollectionKind.rediscover => Icons.history_rounded,
        SmartCollectionKind.artist => Icons.person_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    // Dark, seed-tinted panel so it harmonises with the cover while keeping
    // white type crisp.
    final panelColor =
        Color.alphaBlend(color.withOpacity(0.32), const Color(0xFF0D0D0F));

    final top = (artSeed != null)
        ? AuraArtwork(
            seed: artSeed!,
            fill: true,
            borderRadius: BorderRadius.zero,
            hasArtwork: hasArtwork,
            artworkId: artworkId,
          )
        : ColoredBox(
            color: color,
            child: Center(
              child: Icon(icon, color: Colors.white.withOpacity(0.30), size: 40),
            ),
          );

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
          Expanded(flex: 6, child: top),
          Expanded(flex: 4, child: panel),
        ],
      ),
    );

    if (size == null) return cover;
    return SizedBox(width: size, height: size, child: cover);
  }
}
