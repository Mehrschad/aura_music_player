import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/taste/smart_collection.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/library/collection_actions.dart';
import '../../widgets/library/collection_cover.dart';
import '../../widgets/library/song_list_tile.dart';

/// Opens a smart "For You" collection: its generated cover, play / shuffle /
/// save actions, and the full song list. The collection stays ephemeral — it is
/// only written to the user's playlists if they tap **Save**.
class CollectionDetailPage extends ConsumerWidget {
  const CollectionDetailPage({super.key, required this.collection});

  final SmartCollection collection;

  void _play(WidgetRef ref, int index) {
    HapticFeedback.selectionClick();
    ref
        .read(audioControllerProvider)
        .playQueue(collection.songs, startIndex: index);
  }

  void _shuffle(WidgetRef ref) {
    HapticFeedback.selectionClick();
    final list = [...collection.songs]..shuffle();
    ref.read(audioControllerProvider).playQueue(list, startIndex: 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final songs = collection.songs;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.sm, SpacingTokens.sm, SpacingTokens.sm, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        saveCollectionAsPlaylist(context, ref, collection),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(foregroundColor: colors.accent),
                  ),
                ],
              ),
            ),
            // Header: cover + meta.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CollectionCover.collection(collection, size: 128),
                  const SizedBox(width: SpacingTokens.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          collection.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextTheme.display.copyWith(
                            color: colors.onSurface,
                            fontSize: 24,
                            height: 1.05,
                            letterSpacing: -0.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          collection.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextTheme.body
                              .copyWith(color: colors.onSurfaceMuted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${songs.length} songs',
                          style: AppTextTheme.caption
                              .copyWith(color: colors.onSurfaceFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.md),
            // Play + Shuffle.
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: songs.isEmpty ? null : () => _play(ref, 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: colors.onAccent,
                          shape: const RoundedRectangleBorder(
                              borderRadius: RadiusTokens.brPill),
                          textStyle: AppTextTheme.title
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.sm),
                  SizedBox(
                    height: 50,
                    width: 58,
                    child: OutlinedButton(
                      onPressed: songs.isEmpty ? null : () => _shuffle(ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.divider),
                        shape: const RoundedRectangleBorder(
                            borderRadius: RadiusTokens.brPill),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.shuffle_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            // Song list — each row's actions include "Not interested".
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.md, 0, SpacingTokens.md, SpacingTokens.xl),
                itemCount: songs.length,
                itemBuilder: (_, i) => SongListTile(
                  song: songs[i],
                  onTap: () => _play(ref, i),
                  onLongPress: () =>
                      showRecommendationSongActions(context, ref, songs[i]),
                  onMore: () =>
                      showRecommendationSongActions(context, ref, songs[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
