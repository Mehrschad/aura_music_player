import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/library_sort.dart';
import '../glass/glass_surface.dart';

/// Cycles a section's [DisplayMode] (list → grid → compact → list) and shows
/// the icon for the *current* mode.
class DisplayModeButton extends StatelessWidget {
  const DisplayModeButton({super.key, required this.mode, required this.onChanged});

  final DisplayMode mode;
  final ValueChanged<DisplayMode> onChanged;

  IconData get _icon => switch (mode) {
        DisplayMode.list => Icons.view_list_outlined,
        DisplayMode.grid => Icons.grid_view_outlined,
        DisplayMode.compact => Icons.density_small_outlined,
      };

  DisplayMode get _next => switch (mode) {
        DisplayMode.list => DisplayMode.grid,
        DisplayMode.grid => DisplayMode.compact,
        DisplayMode.compact => DisplayMode.list,
      };

  String _label(DisplayMode m, AppLocalizations l) => switch (m) {
        DisplayMode.list => l.displayList,
        DisplayMode.grid => l.displayGrid,
        DisplayMode.compact => l.displayCompact,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: _label(mode, l10n),
      onPressed: () => onChanged(_next),
      icon: Icon(_icon, color: context.colors.onSurfaceMuted),
    );
  }
}

/// Opens the sort selector. Returns nothing; the chosen [LibrarySort] is
/// delivered via [onChanged] so the caller owns the state.
Future<void> showSortSheet(
  BuildContext context, {
  required LibrarySort current,
  required ValueChanged<LibrarySort> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SortSheet(current: current, onChanged: onChanged),
  );
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current, required this.onChanged});

  final LibrarySort current;
  final ValueChanged<LibrarySort> onChanged;

  static const _fields = SortField.values;

  String _fieldLabel(SortField f, AppLocalizations l) => switch (f) {
        SortField.title => l.sortFieldTitle,
        SortField.artist => l.sortFieldArtist,
        SortField.album => l.sortFieldAlbum,
        SortField.dateAdded => l.sortFieldDateAdded,
        SortField.year => l.sortFieldYear,
        SortField.duration => l.sortFieldDuration,
        SortField.playCount => l.sortFieldPlayCount,
        SortField.lastPlayed => l.sortFieldLastPlayed,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final ascending = current.direction == SortDirection.ascending;

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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.lg,
                  SpacingTokens.md,
                  SpacingTokens.sm,
                  SpacingTokens.sm,
                ),
                child: Row(
                  children: [
                    Text(l10n.sortLabel,
                        style: AppTextTheme.title.copyWith(color: colors.onSurface)),
                    const Spacer(),
                    // Direction toggle.
                    TextButton.icon(
                      onPressed: () => onChanged(current.toggleDirection()),
                      icon: Icon(
                        ascending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: colors.onSurface,
                      ),
                      label: Text(
                        ascending ? l10n.sortAscending : l10n.sortDescending,
                        style: AppTextTheme.body.copyWith(color: colors.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              for (final f in _fields)
                ListTile(
                  dense: true,
                  title: Text(
                    _fieldLabel(f, l10n),
                    style: AppTextTheme.body.copyWith(
                      color: f == current.field ? colors.onSurface : colors.onSurfaceMuted,
                    ),
                  ),
                  trailing: f == current.field
                      ? Icon(Icons.check, size: 18, color: colors.onSurface)
                      : null,
                  onTap: () {
                    onChanged(current.withField(f));
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: SpacingTokens.sm),
            ],
          ),
        ),
      ),
    );
  }
}
