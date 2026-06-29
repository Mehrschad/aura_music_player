import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/seed_color.dart';
import '../widgets/artwork/artwork_image_provider.dart';

/// Immutable key for [coverPaletteProvider]. A record so Riverpod's family
/// caches by value (same song → same palette, no re-extraction on rebuild).
typedef CoverPaletteKey = ({String seed, bool hasArtwork, int? artworkId});

/// Extracts a vivid accent/wash pair from the **real album cover** using
/// Flutter's built-in [ColorScheme.fromImageProvider] (Material Color Utilities
/// — no extra package, no network). Falls back to the deterministic
/// [CoverPalette.fromSeed] when there is no embedded artwork or extraction fails
/// (e.g. in tests, where the platform artwork channel is unavailable).
final coverPaletteProvider =
    FutureProvider.family<CoverPalette, CoverPaletteKey>((ref, key) async {
  if (!key.hasArtwork || key.artworkId == null) {
    return CoverPalette.fromSeed(key.seed);
  }
  try {
    final scheme = await ColorScheme.fromImageProvider(
      provider: ArtworkImageProvider(id: key.artworkId!),
    );
    return CoverPalette.fromColor(scheme.primary);
  } catch (_) {
    return CoverPalette.fromSeed(key.seed);
  }
});
