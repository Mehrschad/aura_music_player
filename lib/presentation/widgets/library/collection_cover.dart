import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../domain/taste/smart_collection.dart';

/// A modern, generated cover: a solid, deterministic colour block with a name
/// set large in monospace, a track count, and a glyph watermark — the
/// Apple-Music / Spotify "text cover" look. No artwork, no gradient. Used for
/// smart collections ([CollectionCover.collection]) and any titled list such as
/// a playlist ([CollectionCover.label]).
class CollectionCover extends StatelessWidget {
  CollectionCover.collection(
    SmartCollection collection, {
    super.key,
    this.size,
    this.radius = RadiusTokens.lg,
  })  : title = collection.title,
        count = collection.songs.length,
        colorSeed = collection.id,
        icon = _glyphForKind(collection.kind);

  const CollectionCover.label({
    super.key,
    required this.title,
    required this.icon,
    required this.colorSeed,
    this.count,
    this.size,
    this.radius = RadiusTokens.lg,
  });

  final String title;

  /// Track count shown as an eyebrow; null hides it (e.g. auto playlists).
  final int? count;
  final IconData icon;

  /// Deterministic colour key (collection id, playlist id…).
  final String colorSeed;

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
    final edge = size ?? 172;
    final titleSize = (edge * 0.135).clamp(15.0, 28.0).toDouble();
    final pad = (edge * 0.085).clamp(12.0, 20.0).toDouble();

    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: _color)),
          // Oversized translucent glyph watermark, bleeding off the corner.
          Positioned(
            right: -edge * 0.14,
            bottom: -edge * 0.16,
            child: Icon(
              icon,
              size: edge * 0.66,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (count != null)
                  Text(
                    '$count TRACKS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _mono,
                      color: Colors.white.withOpacity(0.66),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _mono,
                    color: Colors.white,
                    fontSize: titleSize,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (size == null) return cover;
    return SizedBox(width: size, height: size, child: cover);
  }
}
