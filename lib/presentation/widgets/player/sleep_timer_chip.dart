import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/typography.dart';
import '../../providers/sleep_timer_provider.dart';

/// A compact status chip displayed in the Now Playing screen when the sleep
/// timer is active. Includes a quick +5-min extend button for countdown mode.
class SleepTimerChip extends ConsumerWidget {
  const SleepTimerChip({super.key, required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(sleepTimerProvider);
    if (mode is SleepTimerOff) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    final label = switch (mode) {
      SleepTimerOff() => '',
      SleepTimerCountdown(:final remaining) => remaining.clock,
      SleepTimerEndOfTrack() => l10n.sleepEndOfTrack,
      SleepTimerEndOfNTracks(:final tracksLeft) =>
        l10n.sleepTracksLeft(tracksLeft),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: '${l10n.sleepTimer}: $label',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: RadiusTokens.brSm,
                  border: Border.all(color: accent.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bedtime_outlined, size: 13, color: accent),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: AppTextTheme.caption.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (mode is SleepTimerCountdown) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: l10n.sleepExtend,
                        child: GestureDetector(
                          onTap: () =>
                              ref.read(sleepTimerProvider.notifier).extend(),
                          child: Text(
                            l10n.sleepExtend,
                            style: AppTextTheme.caption.copyWith(
                              color: accent.withOpacity(0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
