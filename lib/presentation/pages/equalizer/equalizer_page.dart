import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../domain/models/named_eq_preset.dart';
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
            userPresets: ref.watch(customEqPresetsProvider),
            onPreset: controller.applyPreset,
            onUserPreset: (preset) {
              // Fully restore the saved curve, bass boost and stereo width.
              controller.setGains(preset.gains);
              controller.setBassBoost(preset.bassBoost);
              controller.setStereoWidth(preset.stereoWidth);
            },
            onSave: () => _saveDialog(context, ref, settings),
            onRename: (id, name) =>
                ref.read(customEqPresetsProvider.notifier).rename(id, name),
            onDelete: (id) =>
                ref.read(customEqPresetsProvider.notifier).remove(id),
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

  /// Prompts for a name, then saves the current curve as a custom preset.
  Future<void> _saveDialog(
      BuildContext context, WidgetRef ref, EqualizerSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final name = await _nameDialog(
      context,
      title: l10n.eqSavePreset,
      initial: l10n.eqCustom,
    );
    if (name == null || name.trim().isEmpty) return;
    final preset = NamedEqPreset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      gains: List<double>.of(settings.gains),
      bassBoost: settings.bassBoost,
      stereoWidth: settings.stereoWidth,
    );
    final messenger = ScaffoldMessenger.of(context);
    final ok = ref.read(customEqPresetsProvider.notifier).add(preset);
    messenger.showSnackBar(SnackBar(
        content: Text(ok ? l10n.eqPresetSaved : l10n.eqPresetLimit)));
  }
}

/// Shared name-entry dialog for saving and renaming presets.
Future<String?> _nameDialog(BuildContext context,
    {required String title, required String initial}) {
  final controller = TextEditingController(text: initial);
  final l10n = AppLocalizations.of(context);
  final colors = context.colors;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surfaceElevated,
      title: Text(title,
          style: AppTextTheme.title.copyWith(color: colors.onSurface)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: AppTextTheme.body.copyWith(color: colors.onSurface),
        decoration: InputDecoration(hintText: l10n.eqPresetName),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.cancel)),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.save)),
      ],
    ),
  );
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
    required this.onRename,
    required this.onDelete,
    required this.accent,
  });

  final EqPreset? selected;
  final List<NamedEqPreset> userPresets;
  final ValueChanged<EqPreset> onPreset;
  final ValueChanged<NamedEqPreset> onUserPreset;
  final VoidCallback onSave;
  final void Function(String id, String name) onRename;
  final ValueChanged<String> onDelete;
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
          for (final preset in userPresets)
            Padding(
              padding: const EdgeInsets.only(right: SpacingTokens.sm),
              child: _Chip(
                label: preset.name,
                selected: false,
                accent: accent,
                onTap: () => onUserPreset(preset),
                onLongPress: () => _presetMenu(context, preset),
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

  /// Long-press menu offering rename and delete for a custom preset.
  Future<void> _presetMenu(BuildContext context, NamedEqPreset preset) async {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: colors.onSurface),
              title: Text(l10n.eqRenamePreset,
                  style: AppTextTheme.body.copyWith(color: colors.onSurface)),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: colors.onSurface),
              title: Text(l10n.eqDeletePreset,
                  style: AppTextTheme.body.copyWith(color: colors.onSurface)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      onDelete(preset.id);
    } else if (action == 'rename' && context.mounted) {
      final name = await _nameDialog(context,
          title: l10n.eqRenamePreset, initial: preset.name);
      if (name != null && name.trim().isNotEmpty) {
        onRename(preset.id, name.trim());
      }
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: onLongPress,
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
