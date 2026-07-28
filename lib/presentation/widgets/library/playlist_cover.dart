import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/song.dart';
import '../artwork/aura_artwork.dart';

/// A playlist's artwork, in priority order:
///  1. a user-chosen [coverPath] image,
///  2. a 2×2 mosaic of the playlist's first songs' covers,
///  3. a single cover when there's only one arted song,
///  4. a deterministic vivid gradient with a music glyph.
///
/// The gradient fallback (keyed on the playlist id) makes even an empty, freshly
/// made playlist look intentional and eye-catching rather than a grey icon box.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.seed,
    required this.songs,
    this.coverPath,
    this.size = 48,
    this.borderRadius,
  });

  /// Deterministic colour key — the playlist id.
  final String seed;

  /// The first few resolved songs, drawn as the mosaic. Empty → gradient.
  final List<Song> songs;

  /// Absolute path to a custom cover image, or null for a generated cover.
  final String? coverPath;

  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? RadiusTokens.brMd;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: size, height: size, child: _content()),
    );
  }

  Widget _content() {
    final path = coverPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    if (songs.isEmpty) return _gradient();
    if (songs.length < 4) return _tile(songs.first, size);
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 2; col++)
                  Expanded(
                    child: _tile(songs[(row * 2 + col) % songs.length], size / 2),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(Song s, double edge) => AuraArtwork(
        seed: s.artworkSeed,
        size: edge,
        borderRadius: BorderRadius.zero,
        hasArtwork: s.hasArtwork,
        artworkId: int.tryParse(s.id),
      );

  Widget _gradient() {
    final a = SeedPalette.accent(seed);
    final b = SeedPalette.wash(seed);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, Color.alphaBlend(Colors.black.withOpacity(0.4), b)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          color: Colors.white.withOpacity(0.85),
          size: size * 0.42,
        ),
      ),
    );
  }
}
