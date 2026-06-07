import 'package:flutter/material.dart';

import '../../core/constants/spacing_tokens.dart';
import '../../core/theme/color_scheme.dart';
import '../../core/theme/typography.dart';

/// The standard top-of-section header: a large display title with an optional
/// subtitle (e.g. "12 songs") and trailing action widgets (sort, display mode).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.xl,
        SpacingTokens.xl,
        SpacingTokens.lg,
        SpacingTokens.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AppTextTheme.display.copyWith(color: colors.onSurface)),
                if (subtitle != null) ...[
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    subtitle!,
                    style:
                        AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
