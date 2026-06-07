import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';

/// Ultra-dense, text-only row. No artwork, tight vertical rhythm.
class SongCompactTile extends StatelessWidget {
  const SongCompactTile({super.key, required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '${song.title}, ${song.artist}',
      child: InkWell(
        onTap: onTap,
        borderRadius: RadiusTokens.brSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.sm,
            vertical: SpacingTokens.xs + 2,
          ),
          child: Row(
            children: [
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
            ],
          ),
        ),
      ),
    );
  }
}
