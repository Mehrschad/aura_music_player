import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';

/// Ultra-dense, text-only row. No artwork, tight vertical rhythm.
///
/// When [selected] is non-null the row is in selection mode and shows a compact
/// check dot; [onTap] toggles and [onLongPress] extends a range. Outside
/// selection mode [onMore] adds the overflow button, so a track carries the same
/// actions here as in the standard row.
class SongCompactTile extends StatelessWidget {
  const SongCompactTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onMore,
    this.onLongPress,
    this.selected,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final VoidCallback? onLongPress;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selecting = selected != null;
    final isSelected = selected ?? false;
    return Semantics(
      button: true,
      label: '${song.title}, ${song.artist}',
      onLongPress: onLongPress,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: RadiusTokens.brSm,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: RadiusTokens.brSm,
            color: isSelected
                ? colors.accent.withOpacity(0.10)
                : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.sm,
            vertical: SpacingTokens.xs + 2,
          ),
          child: Row(
            children: [
              if (selecting) ...[
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color:
                      isSelected ? colors.accent : colors.onSurfaceFaint,
                ),
                const SizedBox(width: SpacingTokens.sm),
              ],
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: AppTextTheme.body.copyWith(color: colors.onSurface),
                    children: [
                      TextSpan(text: song.title),
                      TextSpan(
                        text: '   ${song.artist}',
                        style: AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                song.duration.clock,
                style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
              ),
              if (!selecting && onMore != null)
                InkWell(
                  onTap: onMore,
                  borderRadius: RadiusTokens.brSm,
                  child: Padding(
                    padding: const EdgeInsets.only(left: SpacingTokens.xs),
                    child: Icon(Icons.more_vert,
                        size: 16, color: colors.onSurfaceFaint),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
