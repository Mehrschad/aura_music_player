import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/taste/smart_collection.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../../widgets/library/collection_cover.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';

/// Opens a smart "For You" collection: its generated cover, a play / save
/// header, and the full song list. The collection is still ephemeral — it is
/// only written to the user's playlists if they tap **Save**.
class CollectionDetailPage extends ConsumerWidget {
  const CollectionDetailPage({super.key, required this.collection});

  final SmartCollection collection;

  void _play(WidgetRef ref, int index) {
    HapticFeedback.selectionClick();
    ref.read(audioControllerProvider).playQueue(collection.songs, startIndex: index);
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(playlistRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final created = await repo.create(collection.title);
    await repo.addSongs(created.id, collection.songIds);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved "${collection.title}" to your playlists'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
                    onPressed: () => _save(context, ref),
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
                  CollectionCover(collection: collection, size: 128),
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
            // Play action.
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
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
            const SizedBox(height: SpacingTokens.sm),
            // Song list.
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.md, 0, SpacingTokens.md, SpacingTokens.xl),
                itemCount: songs.length,
                itemBuilder: (_, i) => SongListTile(
                  song: songs[i],
                  onTap: () => _play(ref, i),
                  onLongPress: () => showSongActions(context, songs[i]),
                  onMore: () => showSongActions(context, songs[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
