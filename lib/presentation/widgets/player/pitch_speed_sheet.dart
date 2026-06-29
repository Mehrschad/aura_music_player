import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../providers/playback_providers.dart';
import '../../providers/settings_providers.dart';
import '../glass/glass_surface.dart';

/// Shows the combined speed + pitch bottom sheet.
Future<void> showPitchSpeedSheet(
    BuildContext context, WidgetRef ref, Color accent) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _PitchSpeedSheet(accent: accent),
  );
}

class _PitchSpeedSheet extends ConsumerWidget {
  const _PitchSpeedSheet({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final ctrl = ref.read(audioControllerProvider);
    final currentSpeed = ref.watch(speedProvider).valueOrNull ?? 1.0;
    final currentPitch = ref.watch(pitchProvider).valueOrNull ?? 0.0;
    const speedPresets = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

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
              Text(l10n.speedAndPitch,
                  style:
                      AppTextTheme.title.copyWith(color: colors.onSurface)),
              const SizedBox(height: SpacingTokens.md),
              Text(l10n.playbackSpeed,
                  style: AppTextTheme.caption
                      .copyWith(color: colors.onSurface.withOpacity(0.6))),
              const SizedBox(height: SpacingTokens.sm),
              Wrap(
                spacing: SpacingTokens.sm,
                runSpacing: SpacingTokens.sm,
                children: [
                  for (final p in speedPresets)
                    _SpeedChip(
                      label:
                          '${p % 1 == 0 ? p.toInt() : p}×',
                      selected: (currentSpeed - p).abs() < 0.001,
                      accent: accent,
                      onTap: () => ctrl.setSpeed(p),
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.pitchControl,
                        style: AppTextTheme.caption.copyWith(
                            color: colors.onSurface.withOpacity(0.6))),
                  ),
                  Text(
                    currentPitch == 0.0
                        ? l10n.pitchOriginal
                        : '${currentPitch > 0 ? '+' : ''}${currentPitch.toStringAsFixed(1)} st',
                    style:
                        AppTextTheme.caption.copyWith(color: accent),
                  ),
                ],
              ),
              Slider(
                value: currentPitch,
                min: -12,
                max: 12,
                divisions: 24,
                activeColor: accent,
                onChanged: (v) => ctrl.setPitch(v),
              ),
              if (currentPitch != 0.0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ctrl.setPitch(0.0);
                      ref
                          .read(settingsProvider.notifier)
                          .setPitchSemitones(0.0);
                    },
                    child: Text(l10n.pitchReset,
                        style: AppTextTheme.body.copyWith(color: accent)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = selected
        ? accent.withOpacity(0.16)
        : colors.surface.withOpacity(0.3);
    final fg =
        selected ? accent : colors.onSurface.withOpacity(0.8);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.md, vertical: SpacingTokens.xs),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(RadiusTokens.sm),
          border: Border.all(
              color: selected
                  ? accent
                  : colors.onSurface.withOpacity(0.2)),
        ),
        child: Text(label,
            style: AppTextTheme.body.copyWith(
                color: fg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
