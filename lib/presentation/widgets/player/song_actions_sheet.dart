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
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../artwork/aura_artwork.dart';
import '../glass/glass_surface.dart';

/// The per-song overflow menu: play next, add to queue, add to playlist.
Future<void> showSongActions(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SongActionsSheet(song: song),
  );
}

class _SongActionsSheet extends ConsumerWidget {
  const _SongActionsSheet({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(audioControllerProvider);
    final messenger = ScaffoldMessenger.of(context);

    void closeWith(String message) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: AuraArtwork(
                    seed: song.artworkSeed, size: 44, hasArtwork: song.hasArtwork),
                title: Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.title.copyWith(color: colors.onSurface)),
                subtitle: Text(song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.caption
                        .copyWith(color: colors.onSurfaceMuted)),
              ),
              Divider(color: colors.divider, height: 1),
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
              _action(context, Icons.label_outline, l10n.editTags, () {
                Navigator.of(context).pop();
                openTagEditor(context, [song]);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, color: colors.onSurfaceMuted),
      title: Text(label,
          style: AppTextTheme.body.copyWith(color: colors.onSurface)),
      onTap: onTap,
    );
  }
}

/// Sheet listing user playlists to add [song] to, plus "New playlist".
Future<void> showAddToPlaylist(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToPlaylistSheet(song: song),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.song});
  final Song song;

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
                    await repo.addSongs(created.id, [song.id]);
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
                          repo.addSongs(p.id, [song.id]);
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
