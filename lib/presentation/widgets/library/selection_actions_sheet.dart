import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/library/playlist_logic.dart';
import '../../../domain/models/song.dart';
import '../../pages/tag_editor/tag_editor_page.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/hidden_songs_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/media_actions_provider.dart';
import '../../providers/playback_providers.dart';
import '../../providers/selection_providers.dart';
import '../glass/glass_surface.dart';
import '../player/song_actions_sheet.dart';

/// The bulk-actions sheet for a multi-selection: play, queue, playlist,
/// favourites, tags, hide, export, delete. Acts on [songs] (the resolved
/// selection) and clears the [listId] selection once an action runs.
Future<void> showSelectionActions(
  BuildContext context,
  String listId,
  List<Song> songs,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SelectionActionsSheet(listId: listId, songs: songs),
  );
}

class _SelectionActionsSheet extends ConsumerWidget {
  const _SelectionActionsSheet({required this.listId, required this.songs});

  final String listId;
  final List<Song> songs;

  List<String> get _ids => [for (final s in songs) s.id];

  void _clear(WidgetRef ref) =>
      ref.read(selectionProvider(listId).notifier).clear();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(audioControllerProvider);
    final messenger = ScaffoldMessenger.of(context);

    void closeWith([String? message]) {
      Navigator.of(context).pop();
      _clear(ref);
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }

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
                maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SpacingTokens.lg,
                      SpacingTokens.sm, SpacingTokens.lg, SpacingTokens.sm),
                  child: Text(
                    l10n.selectedCount(songs.length),
                    style: AppTextTheme.title.copyWith(color: colors.onSurface),
                  ),
                ),
                Divider(color: colors.divider, height: 1),
                _action(context, Icons.play_arrow_rounded, l10n.playNow, () {
                  controller.playQueue(songs);
                  closeWith();
                }),
                _action(context, Icons.queue_play_next, l10n.playNext, () {
                  // Insert in reverse so the batch keeps its order after current.
                  for (final s in songs.reversed) {
                    controller.playNext(s);
                  }
                  closeWith(l10n.addedToQueue);
                }),
                _action(context, Icons.add_to_queue, l10n.addToQueue, () {
                  for (final s in songs) {
                    controller.addToQueue(s);
                  }
                  closeWith(l10n.addedToQueue);
                }),
                _action(context, Icons.playlist_add, l10n.addToPlaylist, () {
                  Navigator.of(context).pop();
                  showAddSongsToPlaylist(context, _ids);
                  _clear(ref);
                }),
                Divider(color: colors.divider, height: 1),
                _action(context, Icons.favorite, l10n.addToFavorites, () {
                  ref.read(favoritesProvider.notifier).addAll(_ids);
                  closeWith();
                }),
                _action(context, Icons.favorite_border, l10n.removeFromFavorites,
                    () {
                  ref.read(favoritesProvider.notifier).removeAll(_ids);
                  closeWith();
                }),
                _action(context, Icons.label_outline, l10n.editTags, () {
                  Navigator.of(context).pop();
                  openTagEditor(context, songs);
                  _clear(ref);
                }),
                _action(context, Icons.visibility_off_outlined,
                    l10n.hideFromLibrary, () {
                  ref.read(hiddenSongsProvider.notifier).hideAll(_ids);
                  closeWith(l10n.songsHidden(songs.length));
                }),
                _action(context, Icons.playlist_play, l10n.exportM3u, () {
                  Clipboard.setData(ClipboardData(text: buildM3u8(songs)));
                  closeWith(l10n.playlistCopied);
                }),
                Divider(color: colors.divider, height: 1),
                _action(
                  context,
                  Icons.delete_outline_rounded,
                  l10n.delete,
                  () => _confirmDelete(context, ref),
                  destructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(l10n.deleteSelectedTitle(songs.length),
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        content: Text(l10n.deleteSelectedBody,
            style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ref.read(mediaDeleteServiceProvider);
    var deleted = 0;
    for (final s in songs) {
      if (await service.deleteSong(s.id)) deleted++;
    }
    if (deleted > 0) await ref.read(rescanProvider)();

    if (!context.mounted) return;
    Navigator.of(context).pop();
    _clear(ref);
    messenger.showSnackBar(SnackBar(
      content: Text(deleted > 0 ? l10n.songsDeleted(deleted) : l10n.deleteFailed),
    ));
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final colors = context.colors;
    final color = destructive ? Colors.redAccent : colors.onSurface;
    return ListTile(
      leading: Icon(icon,
          color: destructive ? Colors.redAccent : colors.onSurfaceMuted),
      title:
          Text(label, style: AppTextTheme.body.copyWith(color: color)),
      onTap: onTap,
    );
  }
}
