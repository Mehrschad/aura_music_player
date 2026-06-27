import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../domain/taste/smart_collection.dart';

/// A modern, generated cover for a smart collection: a solid, deterministic
/// colour block with the collection's name set large, plus a small kind glyph
/// and a song count — the Apple-Music / Spotify "text cover" look. No artwork,
/// no gradient. The colour is stable per collection (hashed from its id).
class CollectionCover extends StatelessWidget {
  const CollectionCover({
    super.key,
    required this.collection,
    this.size,
    this.radius = RadiusTokens.lg,
  });

  final SmartCollection collection;

  /// Square edge length; null fills the parent.
  final double? size;
  final double radius;

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
    for (final c in collection.id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  IconData get _glyph => switch (collection.kind) {
        SmartCollectionKind.forYou => Icons.auto_awesome,
        SmartCollectionKind.heavyRotation => Icons.local_fire_department_rounded,
        SmartCollectionKind.hiddenGems => Icons.diamond_outlined,
        SmartCollectionKind.rediscover => Icons.history_rounded,
        SmartCollectionKind.artist => Icons.person_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final edge = size ?? 172;
    final titleSize = (edge * 0.13).clamp(16.0, 30.0).toDouble();
    final pad = (edge * 0.085).clamp(12.0, 22.0).toDouble();

    final cover = DecoratedBox(
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_glyph, color: Colors.white.withOpacity(0.85), size: 18),
            const Spacer(),
            Text(
              '${collection.songs.length} SONGS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              collection.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleSize,
                height: 1.04,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );

    if (size == null) return cover;
    return SizedBox(width: size, height: size, child: cover);
  }
}
