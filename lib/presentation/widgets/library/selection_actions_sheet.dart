import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/library/path_utils.dart';
import '../../../domain/library/playlist_logic.dart';
import '../../../domain/library/rename_pattern.dart';
import '../../../domain/models/song.dart';
import '../../pages/tag_editor/tag_editor_page.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/file_ops_providers.dart';
import '../../providers/hidden_songs_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/media_actions_provider.dart';
import '../../providers/multi_queue_controller.dart';
import '../../providers/playback_providers.dart';
import '../../providers/selection_providers.dart';
import '../../providers/song_ratings_provider.dart';
import '../glass/glass_surface.dart';
import 'star_rating.dart';
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
                _action(context, Icons.dynamic_feed_rounded, l10n.sendToNewQueue,
                    () async {
                  Navigator.of(context).pop();
                  final name = await _promptQueueName(context);
                  if (name != null) {
                    final created = ref
                        .read(multiQueueControllerProvider)
                        .createFrom(name, _ids);
                    messenger.showSnackBar(SnackBar(
                        content: Text(created == null
                            ? l10n.queueLimitReached
                            : l10n.queueSaved)));
                  }
                  _clear(ref);
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
                _action(context, Icons.star_outline_rounded, l10n.rateSong,
                    () async {
                  Navigator.of(context).pop();
                  final r = await _pickRating(context);
                  if (r != null) {
                    ref.read(songRatingsProvider.notifier).setAll(_ids, r);
                  }
                  _clear(ref);
                }),
                _action(context, Icons.drive_file_rename_outline,
                    l10n.bulkRename, () {
                  Navigator.of(context).pop();
                  _bulkRename(context, ref);
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

  /// Opens the tag-pattern rename dialog with a live preview of the first five
  /// selected tracks. Applying renames each file's name in place via the
  /// (overridable) file-ops service.
  Future<void> _bulkRename(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => _BulkRenameDialog(songs: songs),
    );
  }

  /// A compact 1–5 star picker dialog for bulk rating.
  Future<int?> _pickRating(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(l10n.rateSong,
              style: AppTextTheme.title.copyWith(color: colors.onSurface)),
          content: StarRating(
            rating: 0,
            size: 34,
            onRate: (r) => Navigator.of(ctx).pop(r),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel)),
          ],
        );
      },
    );
  }

  Future<String?> _promptQueueName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(l10n.sendToNewQueue,
              style: AppTextTheme.title.copyWith(color: colors.onSurface)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.queueNameHint),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                final v = ctrl.text.trim();
                Navigator.of(ctx).pop(v.isEmpty ? null : v);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
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

class _BulkRenameDialog extends ConsumerStatefulWidget {
  const _BulkRenameDialog({required this.songs});
  final List<Song> songs;

  @override
  ConsumerState<_BulkRenameDialog> createState() => _BulkRenameDialogState();
}

class _BulkRenameDialogState extends ConsumerState<_BulkRenameDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: '{track:02} - {title}.{ext}',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final preview = RenamePattern.preview(widget.songs, _ctrl.text);

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(l10n.bulkRename,
          style: AppTextTheme.title.copyWith(color: colors.onSurface)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(labelText: l10n.renamePattern),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SpacingTokens.md),
            Text(l10n.renamePreview,
                style: AppTextTheme.caption
                    .copyWith(color: colors.onSurfaceFaint)),
            const SizedBox(height: SpacingTokens.xs),
            for (final row in preview)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  PathUtils.basename(row.result),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.caption.copyWith(color: colors.onSurface),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => _apply(context),
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _apply(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ops = ref.read(fileOpsServiceProvider);
    final pattern = _ctrl.text;
    Navigator.of(context).pop();

    var renamed = 0;
    for (final s in widget.songs) {
      final newName = PathUtils.basename(RenamePattern.render(pattern, s));
      if (newName.isEmpty) continue;
      if (await ops.rename(s.filePath, newName) != null) renamed++;
    }
    if (renamed > 0) await ref.read(rescanProvider)();
    messenger.showSnackBar(SnackBar(
      content: Text(renamed > 0 ? l10n.filesRenamed(renamed) : l10n.renameFailed),
    ));
  }
}
