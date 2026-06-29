import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';
import '../../providers/ab_repeat_provider.dart';
import '../../providers/playback_providers.dart';

/// A row of [A] · [B] · [Clear] buttons shown below the scrubber.
/// Long-listening sessions use A-B repeat to loop a region of the track.
class ABRepeatControls extends ConsumerWidget {
  const ABRepeatControls({super.key, required this.accent, required this.song});
  final Color accent;
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ab = ref.watch(abRepeatProvider);
    final notifier = ref.read(abRepeatProvider.notifier);
    final isCurrent = ab.songId == song.id;
    final a = isCurrent ? ab.pointA : null;
    final b = isCurrent ? ab.pointB : null;
    final hasAny = a != null || b != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ABBtn(
            label: a != null ? 'A · ${a.clock}' : l10n.abSetA,
            active: a != null,
            accent: accent,
            semanticLabel: l10n.abSetA,
            onTap: () {
              final pos =
                  ref.read(positionProvider).valueOrNull ?? Duration.zero;
              notifier.setA(song.id, pos);
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(width: SpacingTokens.xs),
          _ABBtn(
            label: b != null ? 'B · ${b.clock}' : l10n.abSetB,
            active: b != null,
            accent: accent,
            semanticLabel: l10n.abSetB,
            onTap: () {
              final pos =
                  ref.read(positionProvider).valueOrNull ?? Duration.zero;
              notifier.setB(song.id, pos);
              HapticFeedback.selectionClick();
            },
          ),
          if (hasAny) ...[
            const SizedBox(width: SpacingTokens.xs),
            _ABBtn(
              label: l10n.abClear,
              active: false,
              accent: accent,
              isDestructive: true,
              semanticLabel: l10n.abClear,
              onTap: () {
                notifier.clear();
                HapticFeedback.selectionClick();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ABBtn extends StatelessWidget {
  const _ABBtn({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
    required this.semanticLabel,
    this.isDestructive = false,
  });

  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = isDestructive
        ? colors.danger
        : active
            ? accent
            : colors.onSurfaceMuted;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? accent.withOpacity(0.13)
                : colors.surfaceElevated.withOpacity(0.6),
            borderRadius: RadiusTokens.brSm,
            border:
                active ? Border.all(color: accent.withOpacity(0.35)) : null,
          ),
          child: Text(
            label,
            style: AppTextTheme.caption.copyWith(
              color: fg,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
