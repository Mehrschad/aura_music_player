import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/equalizer.dart';
import '../../providers/equalizer_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/equalizer/band_slider.dart';
import '../../widgets/equalizer/eq_curve_painter.dart';

Future<void> openEqualizer(BuildContext context) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: context.motion(MotionTokens.screen),
    pageBuilder: (_, __, ___) => const EqualizerPage(),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: MotionTokens.standard),
      child: child,
    ),
  ));
}

String presetLabel(EqPreset p, AppLocalizations l) => switch (p) {
      EqPreset.flat => l.presetFlat,
      EqPreset.bassBoost => l.presetBassBoost,
      EqPreset.vocalClarity => l.presetVocalClarity,
      EqPreset.electronic => l.presetElectronic,
      EqPreset.acoustic => l.presetAcoustic,
      EqPreset.hipHop => l.presetHipHop,
      EqPreset.classical => l.presetClassical,
      EqPreset.rock => l.presetRock,
      EqPreset.hifi => l.presetHiFi,
    };

class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(equalizerControllerProvider);
    final settings = ref.watch(equalizerSettingsProvider).valueOrNull ??
        controller.settings;
    final selected = ref.watch(selectedPresetProvider);
    final song = ref.watch(currentSongProvider);
    final accent = SeedPalette.accent(song?.artworkSeed ?? 'eq');

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(l10n.equalizer,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        actions: [
          TextButton(
            onPressed: () => controller.applyPreset(EqPreset.flat),
            child: Text(l10n.eqReset),
          ),
          Switch(
            value: settings.enabled,
            onChanged: controller.setEnabled,
          ),
          const SizedBox(width: SpacingTokens.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: SpacingTokens.xxl),
        children: [
          _PresetChips(
            selected: selected,
            userPresets: ref.watch(userEqPresetsProvider),
            onPreset: controller.applyPreset,
            onUserPreset: (gains) => controller.setGains(gains),
            onSave: () {
              final slots = List<List<double>?>.of(
                  ref.read(userEqPresetsProvider));
              final i = slots.indexWhere((s) => s == null);
              final target = i == -1 ? slots.length - 1 : i;
              slots[target] = List<double>.of(settings.gains);
              ref.read(userEqPresetsProvider.notifier).state = slots;
            },
            accent: accent,
          ),
          Opacity(
            opacity: settings.enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !settings.enabled,
              child: _EqGraph(
                gains: settings.gains,
                accent: accent,
                onBandChanged: controller.setBandGain,
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          _BassBoost(
            value: settings.bassBoost,
            accent: accent,
            onChanged: (v) => controller.setBassBoost(v),
          ),
          _StereoWidener(
            value: settings.stereoWidth,
            accent: accent,
            onChanged: controller.setStereoWidth,
          ),
        ],
      ),
    );
  }
}

class _EqGraph extends StatelessWidget {
  const _EqGraph({
    required this.gains,
    required this.accent,
    required this.onBandChanged,
  });

  final List<double> gains;
  final Color accent;
  final void Function(int index, double db) onBandChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.lg, vertical: SpacingTokens.md),
      child: SizedBox(
        height: 240,
        child: Stack(
          children: [
            // Animated response curve behind the sliders.
            Positioned.fill(
              bottom: 22, // leave room for band labels
              child: TweenAnimationBuilder<List<double>>(
                tween: GainsTween(end: gains),
                duration: context.motion(MotionTokens.micro),
                curve: MotionTokens.standard,
                builder: (context, value, _) => CustomPaint(
                  painter: EqCurvePainter(
                    gains: value,
                    accent: accent,
                    baseline: colors.divider,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < gains.length; i++)
                  Expanded(
                    child: BandSlider(
                      gain: gains[i],
                      label: eqBandLabel(kEqBands[i]),
                      accent: accent,
                      onChanged: (db) => onBandChanged(i, db),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChips extends StatelessWidget {
  const _PresetChips({
    required this.selected,
    required this.userPresets,
    required this.onPreset,
    required this.onUserPreset,
    required this.onSave,
    required this.accent,
  });

  final EqPreset? selected;
  final List<List<double>?> userPresets;
  final ValueChanged<EqPreset> onPreset;
  final ValueChanged<List<double>> onUserPreset;
  final VoidCallback onSave;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
        children: [
          for (final preset in EqPreset.values)
            Padding(
              padding: const EdgeInsets.only(right: SpacingTokens.sm),
              child: _Chip(
                label: presetLabel(preset, l10n),
                selected: preset == selected,
                accent: accent,
                onTap: () => onPreset(preset),
              ),
            ),
          for (var i = 0; i < userPresets.length; i++)
            if (userPresets[i] != null)
              Padding(
                padding: const EdgeInsets.only(right: SpacingTokens.sm),
                child: _Chip(
                  label: '${l10n.eqCustom} ${i + 1}',
                  selected: false,
                  accent: accent,
                  onTap: () => onUserPreset(userPresets[i]!),
                ),
              ),
          ActionChip(
            avatar: Icon(Icons.add, size: 16, color: colors.onSurface),
            label: Text(l10n.eqSavePreset),
            backgroundColor: colors.surfaceElevated,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
        decoration: BoxDecoration(
          color: selected ? accent : colors.surfaceElevated,
          borderRadius: RadiusTokens.brPill,
        ),
        child: Text(
          label,
          style: AppTextTheme.body.copyWith(
            color: selected ? colors.background : colors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _BassBoost extends StatelessWidget {
  const _BassBoost(
      {required this.value, required this.accent, required this.onChanged});

  final int value;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.eqBassBoost,
              style: AppTextTheme.body.copyWith(color: colors.onSurface)),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              inactiveTrackColor: colors.divider,
              thumbColor: accent,
              overlayColor: accent.withOpacity(0.16),
            ),
            child: Slider(
              value: value.toDouble(),
              max: kBassBoostMax.toDouble(),
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _StereoWidener extends StatelessWidget {
  const _StereoWidener(
      {required this.value, required this.accent, required this.onChanged});

  final double value;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(l10n.eqStereoWidener,
                style: AppTextTheme.body.copyWith(color: colors.onSurface)),
          ),
          SizedBox(
            width: 160,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accent,
                inactiveTrackColor: colors.divider,
                thumbColor: accent,
                overlayColor: accent.withOpacity(0.16),
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }
}
