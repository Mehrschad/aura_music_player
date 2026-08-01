import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';
import '../../pages/playlists/playlist_dialogs.dart';
import '../../pages/tag_editor/tag_editor_page.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../../providers/song_ratings_provider.dart';
import '../artwork/aura_artwork.dart';
import '../glass/glass_surface.dart';
import '../library/song_actions_common.dart';
import '../library/star_rating.dart';
import 'song_share.dart';

/// The per-song action sheet — the single menu every surface that lists a track
/// opens, so a song offers the same actions in the library, search, an album, an
/// artist, a genre, a folder, a playlist, or the queue.
///
/// [onRemove] adds a context-specific removal entry (labelled [removeLabel]) —
/// e.g. "Remove from playlist" inside a playlist, "Remove from queue" in the
/// queue. Omit it on surfaces where the song has no container to be removed
/// from.
Future<void> showSongActions(
  BuildContext context,
  Song song, {
  VoidCallback? onRemove,
  String? removeLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SongActionsSheet(
      song: song,
      onRemove: onRemove,
      removeLabel: removeLabel,
    ),
  );
}

class _SongActionsSheet extends ConsumerWidget {
  const _SongActionsSheet({
    required this.song,
    this.onRemove,
    this.removeLabel,
  });

  final Song song;
  final VoidCallback? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(audioControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final isFavorite = ref.watch(isFavoriteProvider(song.id));

    void closeWith(String message) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: ConstrainedBox(
          // The list is long now — cap it and scroll inside the glass card so
          // the destructive actions at the bottom stay reachable.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: GlassSurface(
            borderRadius: RadiusTokens.brLg,
            intensity: GlassIntensity.strong,
            padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: AuraArtwork(
                        seed: song.artworkSeed,
                        size: 44,
                        hasArtwork: song.hasArtwork,
                        artworkId: int.tryParse(song.id)),
                    title: Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.title
                            .copyWith(color: colors.onSurface)),
                    subtitle: Text('${song.artist} · ${song.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.caption
                            .copyWith(color: colors.onSurfaceMuted)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, 0,
                        SpacingTokens.lg, SpacingTokens.sm),
                    child: Row(
                      children: [
                        Text(l10n.rateSong,
                            style: AppTextTheme.caption
                                .copyWith(color: colors.onSurfaceMuted)),
                        const Spacer(),
                        StarRating(
                          rating: ref.watch(songRatingProvider(song.id)) ?? 0,
                          onRate: (r) => ref
                              .read(songRatingsProvider.notifier)
                              .setRating(song.id, r),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: colors.divider, height: 1),
                  _action(
                    context,
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
                    () {
                      ref.read(favoritesProvider.notifier).toggle(song.id);
                      Navigator.of(context).pop();
                    },
                    tint: isFavorite ? colors.favorite : null,
                  ),
                  _action(context, Icons.queue_play_next, l10n.playNext, () {
                    controller.playNext(song);
                    closeWith(l10n.addedToQueue);
                  }),
                  _action(context, Icons.add_to_queue, l10n.addToQueue, () {
                    controller.addToQueue(song);
                    closeWith(l10n.addedToQueue);
                  }),
                  _action(context, Icons.playlist_add, l10n.addToPlaylist, () {
                    Navigator.of(context).pop();
                    showAddToPlaylist(context, song);
                  }),
                  if (onRemove != null)
                    _action(
                      context,
                      Icons.playlist_remove,
                      removeLabel ?? l10n.removeFromPlaylist,
                      () {
                        Navigator.of(context).pop();
                        onRemove!();
                      },
                    ),
                  Divider(color: colors.divider, height: 1),
                  _action(context, Icons.share_outlined, 'Share', () {
                    // Share first so the sheet is still laid out — its rect
                    // anchors the OS share popover — then dismiss.
                    shareSong(context, song);
                    Navigator.of(context).pop();
                  }),
                  _action(context, Icons.album_outlined, l10n.goToAlbum, () {
                    Navigator.of(context).pop();
                    openAlbumForSong(context, ref, song);
                  }),
                  _action(context, Icons.person_outline, l10n.goToArtist, () {
                    Navigator.of(context).pop();
                    openArtistForSong(context, ref, song);
                  }),
                  _action(context, Icons.info_outline, l10n.songInfo, () {
                    Navigator.of(context).pop();
                    showSongInfo(context, song);
                  }),
                  _action(context, Icons.label_outline, l10n.editTags, () {
                    Navigator.of(context).pop();
                    openTagEditor(context, [song]);
                  }),
                  Divider(color: colors.divider, height: 1),
                  _action(context, Icons.delete_outline, l10n.delete, () {
                    Navigator.of(context).pop();
                    confirmAndDeleteSong(context, ref, song);
                  }, tint: colors.danger),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? tint,
  }) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, color: tint ?? colors.onSurfaceMuted),
      title: Text(label,
          style: AppTextTheme.body.copyWith(color: tint ?? colors.onSurface)),
      onTap: onTap,
    );
  }
}

/// Sheet listing user playlists to add [song] to, plus "New playlist".
Future<void> showAddToPlaylist(BuildContext context, Song song) {
  return showAddSongsToPlaylist(context, [song.id]);
}

/// Sheet listing user playlists to add a batch of [songIds] to (Step 16 bulk
/// action), plus "New playlist". Shares the same UI as the single-song variant.
Future<void> showAddSongsToPlaylist(
    BuildContext context, List<String> songIds) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToPlaylistSheet(songIds: songIds),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.songIds});
  final List<String> songIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(playlistRepositoryProvider);
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final messenger = ScaffoldMessenger.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SpacingTokens.lg,
                      SpacingTokens.md, SpacingTokens.lg, SpacingTokens.sm),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(l10n.addToPlaylist,
                        style: AppTextTheme.title
                            .copyWith(color: colors.onSurface)),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.add, color: colors.onSurface),
                  title: Text(l10n.playlistNew,
                      style:
                          AppTextTheme.body.copyWith(color: colors.onSurface)),
                  onTap: () async {
                    final name = await promptPlaylistName(context);
                    if (name == null) return;
                    final created = await repo.create(name);
                    await repo.addSongs(created.id, songIds);
                    if (context.mounted) Navigator.of(context).pop();
                    messenger.showSnackBar(
                        SnackBar(content: Text(l10n.addedToPlaylist)));
                  },
                ),
                Divider(color: colors.divider, height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (_, i) {
                      final p = playlists[i];
                      return ListTile(
                        leading:
                            Icon(Icons.queue_music, color: colors.onSurfaceMuted),
                        title: Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextTheme.body
                                .copyWith(color: colors.onSurface)),
                        subtitle: Text(l10n.songsCount(p.length),
                            style: AppTextTheme.caption
                                .copyWith(color: colors.onSurfaceFaint)),
                        onTap: () {
                          repo.addSongs(p.id, songIds);
                          Navigator.of(context).pop();
                          messenger.showSnackBar(
                              SnackBar(content: Text(l10n.addedToPlaylist)));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
