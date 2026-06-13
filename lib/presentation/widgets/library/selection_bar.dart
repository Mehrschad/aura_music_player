import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';
import '../../providers/selection_providers.dart';
import 'selection_actions_sheet.dart';

/// The header that replaces a section's title row while selection mode is
/// active: close, "{n} selected", select-all, invert, and the bulk-actions
/// overflow. Drives the [selectionProvider] for [listId]; [allSongs] is the
/// list's current full contents (for select-all / invert and to resolve the
/// picked songs for the actions sheet).
class SelectionBar extends ConsumerWidget {
  const SelectionBar({
    super.key,
    required this.listId,
    required this.allSongs,
  });

  final String listId;
  final List<Song> allSongs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(selectionProvider(listId));
    final notifier = ref.read(selectionProvider(listId).notifier);
    final allIds = [for (final s in allSongs) s.id];

    void close() {
      HapticFeedback.selectionClick();
      notifier.clear();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.lg,
        SpacingTokens.xl,
        SpacingTokens.sm,
        SpacingTokens.md,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.cancel,
            onPressed: close,
            icon: Icon(Icons.close, color: colors.onSurface),
          ),
          Expanded(
            child: Text(
              l10n.selectedCount(selection.count),
              style: AppTextTheme.title.copyWith(color: colors.onSurface),
            ),
          ),
          IconButton(
            tooltip: l10n.selectAll,
            onPressed: () => notifier.selectAll(allIds),
            icon: Icon(Icons.select_all, color: colors.onSurfaceMuted),
          ),
          IconButton(
            tooltip: l10n.invertSelection,
            onPressed: () => notifier.invert(allIds),
            icon: Icon(Icons.flip_to_back, color: colors.onSurfaceMuted),
          ),
          IconButton(
            tooltip: l10n.moreActions,
            onPressed: selection.isEmpty
                ? null
                : () {
                    final picked = [
                      for (final s in allSongs)
                        if (selection.contains(s.id)) s,
                    ];
                    showSelectionActions(context, listId, picked);
                  },
            icon: Icon(Icons.more_vert, color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}
