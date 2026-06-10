import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../providers/playback_providers.dart';
import '../artwork/aura_artwork.dart';
import '../glass/glass_surface.dart';

/// Opens the queue panel: the current queue with the playing track highlighted.
/// Tap a row to jump to it, drag the handle to reorder, swipe to remove.
Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(audioControllerProvider);
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final queue = state?.queue ?? const [];
    final currentIndex = state?.currentIndex;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SpacingTokens.lg,
                      SpacingTokens.lg, SpacingTokens.lg, SpacingTokens.sm),
                  child: Row(
                    children: [
                      Text(l10n.queueTitle,
                          style: AppTextTheme.title
                              .copyWith(color: colors.onSurface)),
                      const Spacer(),
                      Text(l10n.songsCount(queue.length),
                          style: AppTextTheme.caption
                              .copyWith(color: colors.onSurfaceFaint)),
                    ],
                  ),
                ),
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      controller.moveInQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (context, i) {
                      final song = queue[i];
                      final isCurrent = i == currentIndex;
                      return Dismissible(
                        key: ValueKey('queue_${song.id}_$i'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => controller.removeFromQueue(i),
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding:
                              const EdgeInsets.only(right: SpacingTokens.xl),
                          child: Icon(Icons.delete_outline,
                              color: colors.onSurfaceMuted),
                        ),
                        child: ListTile(
                          leading: AuraArtwork(
                              seed: song.artworkSeed,
                              size: 40,
                              hasArtwork: song.hasArtwork,
                              artworkId: int.tryParse(song.id)),
                          title: Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextTheme.body.copyWith(
                                  color: isCurrent
                                      ? colors.onSurface
                                      : colors.onSurfaceMuted, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400)),
                          subtitle: Text(song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextTheme.caption
                                  .copyWith(color: colors.onSurfaceFaint)),
                          trailing: isCurrent
                              ? Icon(Icons.equalizer,
                                  size: 18, color: colors.onSurface)
                              : ReorderableDragStartListener(
                                  index: i,
                                  child: Icon(Icons.drag_handle,
                                      color: colors.onSurfaceFaint),
                                ),
                          onTap: () {
                            controller.skipToIndex(i);
                            Navigator.of(context).pop();
                          },
                        ),
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
