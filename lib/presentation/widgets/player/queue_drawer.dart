import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/queue_colors.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/named_queue.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_providers.dart';
import '../../providers/multi_queue_controller.dart';
import '../../providers/queue_registry_provider.dart';
import '../artwork/aura_artwork.dart';
import '../glass/glass_surface.dart';

/// Opens the named-queue picker drawer.
Future<void> showQueueDrawer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _QueueDrawer(),
  );
}

class _QueueDrawer extends ConsumerWidget {
  const _QueueDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final queues = ref.watch(queueRegistryProvider);
    final activeId = ref.watch(activeQueueIdProvider);
    final byId = <String, Song>{
      for (final s in ref.watch(effectiveSongsProvider).valueOrNull ?? const [])
        s.id: s,
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SpacingTokens.lg,
                      SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.sm),
                  child: Row(
                    children: [
                      Text(l10n.queues,
                          style: AppTextTheme.title
                              .copyWith(color: colors.onSurface)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: Text(l10n.saveQueueAs),
                        onPressed: () => _saveCurrentAs(context, ref),
                      ),
                    ],
                  ),
                ),
                if (queues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(SpacingTokens.xxl),
                    child: Text(l10n.noQueues,
                        style: AppTextTheme.body
                            .copyWith(color: colors.onSurfaceMuted)),
                  )
                else
                  Flexible(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.only(bottom: SpacingTokens.sm),
                      itemCount: queues.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        ref
                            .read(queueRegistryProvider.notifier)
                            .reorder(oldIndex, newIndex);
                      },
                      itemBuilder: (context, i) {
                        final q = queues[i];
                        return _QueueRow(
                          key: ValueKey(q.id),
                          queue: q,
                          songsById: byId,
                          active: q.id == activeId,
                          index: i,
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

  Future<void> _saveCurrentAs(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptName(context, l10n.saveQueueAs);
    if (name == null) return;
    final created =
        ref.read(multiQueueControllerProvider).saveCurrentAs(name);
    messenger.showSnackBar(SnackBar(
        content: Text(
            created == null ? l10n.queueLimitReached : l10n.queueSaved)));
  }
}

class _QueueRow extends ConsumerWidget {
  const _QueueRow({
    super.key,
    required this.queue,
    required this.songsById,
    required this.active,
    required this.index,
  });

  final NamedQueue queue;
  final Map<String, Song> songsById;
  final bool active;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final tint = QueueColors.at(queue.colorIndex);
    final songs = <Song>[
      for (final id in queue.songIds)
        if (songsById[id] != null) songsById[id]!,
    ];

    return ListTile(
      leading: _Mosaic(songs: songs, tint: tint),
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsetsDirectional.only(end: SpacingTokens.xs),
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          Flexible(
            child: Text(queue.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.body.copyWith(
                    color: colors.onSurface,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ),
          if (queue.kind == QueueKind.audiobook)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: SpacingTokens.xs),
              child: Icon(Icons.menu_book_outlined,
                  size: 13, color: colors.onSurfaceFaint),
            ),
          if (queue.kind == QueueKind.podcast)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: SpacingTokens.xs),
              child: Icon(Icons.podcasts_outlined,
                  size: 13, color: colors.onSurfaceFaint),
            ),
        ],
      ),
      subtitle: Text(
        '${l10n.songsCount(queue.length)} · ${l10n.queuePlays(queue.playCount)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            Icon(Icons.graphic_eq_rounded, size: 18, color: tint),
          IconButton(
            icon: Icon(Icons.more_vert, color: colors.onSurfaceMuted),
            onPressed: () => _showRowMenu(context, ref),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, color: colors.onSurfaceFaint),
          ),
        ],
      ),
      onTap: () async {
        HapticFeedback.selectionClick();
        await ref.read(multiQueueControllerProvider).switchTo(queue.id);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  Future<void> _showRowMenu(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reg = ref.read(queueRegistryProvider.notifier);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
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
                  _Tile(
                    icon: Icons.drive_file_rename_outline,
                    label: l10n.rename,
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      final name = await _promptName(context, l10n.rename,
                          initial: queue.name);
                      if (name != null) reg.rename(queue.id, name);
                    },
                  ),
                  _Tile(
                    icon: Icons.palette_outlined,
                    label: l10n.queueColor,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _showColorPicker(context, ref);
                    },
                  ),
                  _Tile(
                    icon: Icons.copy_all_outlined,
                    label: l10n.duplicate,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      reg.duplicate(queue.id);
                    },
                  ),
                  _Tile(
                    icon: Icons.menu_book_outlined,
                    label: l10n.treatAsAudiobook,
                    trailing: queue.kind == QueueKind.audiobook,
                    onTap: () {
                      reg.setKind(
                          queue.id,
                          queue.kind == QueueKind.audiobook
                              ? QueueKind.normal
                              : QueueKind.audiobook);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                  _Tile(
                    icon: Icons.podcasts_outlined,
                    label: l10n.treatAsPodcast,
                    trailing: queue.kind == QueueKind.podcast,
                    onTap: () {
                      reg.setKind(
                          queue.id,
                          queue.kind == QueueKind.podcast
                              ? QueueKind.normal
                              : QueueKind.podcast);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                  _Tile(
                    icon: Icons.delete_outline_rounded,
                    label: l10n.delete,
                    destructive: true,
                    onTap: () {
                      reg.delete(queue.id);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showColorPicker(BuildContext context, WidgetRef ref) {
    final reg = ref.read(queueRegistryProvider.notifier);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final l10n = AppLocalizations.of(sheetCtx);
        final colors = sheetCtx.colors;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.md),
            child: GlassSurface(
              borderRadius: RadiusTokens.brLg,
              intensity: GlassIntensity.strong,
              padding: const EdgeInsets.all(SpacingTokens.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.queueColor,
                      style: AppTextTheme.title
                          .copyWith(color: colors.onSurface)),
                  const SizedBox(height: SpacingTokens.md),
                  Wrap(
                    spacing: SpacingTokens.sm,
                    runSpacing: SpacingTokens.sm,
                    children: [
                      for (var i = 0; i < QueueColors.count; i++)
                        Semantics(
                          button: true,
                          selected: i == queue.colorIndex,
                          child: GestureDetector(
                            onTap: () {
                              reg.recolor(queue.id, i);
                              Navigator.pop(sheetCtx);
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: QueueColors.at(i),
                                shape: BoxShape.circle,
                                border: i == queue.colorIndex
                                    ? Border.all(
                                        color: colors.onSurface, width: 2)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A 2×2 album-art mosaic from up to four of the queue's songs.
class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.songs, required this.tint});
  final List<Song> songs;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    const side = 44.0;
    if (songs.isEmpty) {
      return Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: tint.withOpacity(0.18),
          borderRadius: RadiusTokens.brXs,
        ),
        child: Icon(Icons.queue_music_rounded, size: 20, color: tint),
      );
    }
    final tiles = songs.take(4).toList();
    return ClipRRect(
      borderRadius: RadiusTokens.brXs,
      child: SizedBox(
        width: side,
        height: side,
        child: tiles.length == 1
            ? AuraArtwork(
                seed: tiles[0].artworkSeed,
                size: side,
                hasArtwork: tiles[0].hasArtwork,
                artworkId: int.tryParse(tiles[0].id))
            : GridView.count(
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final s in tiles)
                    AuraArtwork(
                        seed: s.artworkSeed,
                        size: side / 2,
                        hasArtwork: s.hasArtwork,
                        artworkId: int.tryParse(s.id)),
                ],
              ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.trailing = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? Colors.redAccent : colors.onSurface;
    return ListTile(
      leading: Icon(icon,
          color: destructive ? Colors.redAccent : colors.onSurfaceMuted),
      title: Text(label, style: AppTextTheme.body.copyWith(color: color)),
      trailing: trailing
          ? Icon(Icons.check_rounded, color: colors.accent, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

/// Shared name dialog used by save / rename.
Future<String?> _promptName(BuildContext context, String title,
    {String? initial}) {
  final l10n = AppLocalizations.of(context);
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final colors = ctx.colors;
      return AlertDialog(
        backgroundColor: colors.surface,
        title: Text(title,
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
            child: Text(l10n.cancel),
          ),
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
