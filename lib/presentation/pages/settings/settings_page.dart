import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/app_settings.dart';
import '../../providers/library_providers.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/settings_providers.dart';
import '../equalizer/equalizer_page.dart';
import 'widget_preview_page.dart';

Future<void> openSettings(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
  );
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(l10n.settings,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: SpacingTokens.xxl),
        children: [
          // ── Appearance ──
          _Header(l10n.settingsAppearance),
          _Chips<ThemePref>(
            label: l10n.theme,
            values: ThemePref.values,
            current: s.themePref,
            labelFor: (t) => switch (t) {
              ThemePref.system => l10n.themeSystem,
              ThemePref.light => l10n.themeLight,
              ThemePref.dark => l10n.themeDark,
              ThemePref.amoled => l10n.themeAmoled,
            },
            onSelect: n.setTheme,
          ),
          _Chips<GlassIntensity>(
            label: l10n.glassIntensity,
            values: GlassIntensity.values,
            current: s.glassIntensity,
            labelFor: (g) => switch (g) {
              GlassIntensity.off => l10n.glassOff,
              GlassIntensity.subtle => l10n.glassSubtle,
              GlassIntensity.medium => l10n.glassMedium,
              GlassIntensity.strong => l10n.glassStrong,
            },
            onSelect: n.setGlassIntensity,
          ),
          _SwitchTile(
              label: l10n.dynamicColor,
              value: s.dynamicColor,
              onChanged: n.setDynamicColor),
          _SliderTile(
            label: l10n.textScale,
            value: s.textScale,
            min: 0.85,
            max: 1.3,
            divisions: 9,
            display: '${(s.textScale * 100).round()}%',
            onChanged: n.setTextScale,
          ),
          _Chips<DisplayDensity>(
            label: l10n.density,
            values: DisplayDensity.values,
            current: s.density,
            labelFor: (d) => switch (d) {
              DisplayDensity.comfortable => l10n.densityComfortable,
              DisplayDensity.standard => l10n.densityStandard,
              DisplayDensity.compact => l10n.densityCompact,
            },
            onSelect: n.setDensity,
          ),
          _Chips<LocalePref>(
            label: l10n.language,
            values: LocalePref.values,
            current: s.locale,
            labelFor: (lp) => switch (lp) {
              LocalePref.system => l10n.langSystem,
              LocalePref.en => l10n.langEn,
              LocalePref.fa => l10n.langFa,
              LocalePref.ar => l10n.langAr,
            },
            onSelect: n.setLocale,
          ),

          // ── Library ──
          _Header(l10n.settingsLibrary),
          _FolderList(folders: s.sourceFolders, notifier: n),
          _SwitchTile(
              label: l10n.scanOnStartup,
              value: s.scanOnStartup,
              onChanged: n.setScanOnStartup),
          _SwitchTile(
              label: l10n.showHidden,
              value: s.showHidden,
              onChanged: n.setShowHidden),
          _NavTile(
            label: l10n.rescanNow,
            icon: Icons.refresh,
            onTap: () => ref.read(rescanProvider)(),
          ),

          // ── Playback ──
          _Header(l10n.settingsPlayback),
          _SliderTile(
            label: l10n.crossfade,
            value: s.crossfadeSeconds,
            min: 0,
            max: 12,
            divisions: 12,
            display: '${s.crossfadeSeconds.round()}s',
            onChanged: n.setCrossfade,
          ),
          _Chips<ReplayGainMode>(
            label: l10n.replayGain,
            values: ReplayGainMode.values,
            current: s.replayGain,
            labelFor: (r) => switch (r) {
              ReplayGainMode.off => l10n.replayOff,
              ReplayGainMode.track => l10n.replayTrack,
              ReplayGainMode.album => l10n.replayAlbum,
            },
            onSelect: n.setReplayGain,
          ),
          _SwitchTile(
              label: l10n.gapless, value: s.gapless, onChanged: n.setGapless),
          _SwitchTile(
              label: l10n.speedMemory,
              value: s.speedMemory,
              onChanged: n.setSpeedMemory),
          _Chips<InterruptionBehavior>(
            label: l10n.interruption,
            values: InterruptionBehavior.values,
            current: s.interruption,
            labelFor: (i) => switch (i) {
              InterruptionBehavior.pause => l10n.interruptPause,
              InterruptionBehavior.duck => l10n.interruptDuck,
              InterruptionBehavior.ignore => l10n.interruptIgnore,
            },
            onSelect: n.setInterruption,
          ),

          // ── Equalizer ──
          _Header(l10n.settingsEqualizer),
          _NavTile(
            label: l10n.manageEqualizer,
            icon: Icons.graphic_eq,
            onTap: () => openEqualizer(context),
          ),

          // ── Lyrics ──
          _Header(l10n.settingsLyrics),
          _SwitchTile(
              label: l10n.lyricsAutoFetch,
              value: s.lyricsAutoFetch,
              onChanged: n.setLyricsAutoFetch),
          _TextTile(
            label: l10n.geniusApiKey,
            value: s.geniusApiKey,
            obscure: true,
            onChanged: n.setGeniusApiKey,
          ),
          _NavTile(
            label: l10n.clearCache,
            icon: Icons.delete_sweep_outlined,
            onTap: () {
              ref.read(lyricsOverridesProvider.notifier).clear();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.cacheCleared)));
            },
          ),

          // ── Integrations ──
          _Header(l10n.settingsIntegrations),
          _NavTile(
            label: l10n.homeWidgets,
            icon: Icons.widgets_outlined,
            onTap: () => openWidgetPreview(context),
          ),
          _SwitchTile(
              label: l10n.lastFm,
              value: s.lastFmEnabled,
              onChanged: n.setLastFm),
          _SwitchTile(
              label: l10n.androidAuto,
              value: s.androidAuto,
              onChanged: n.setAndroidAuto),

          // ── About ──
          _Header(l10n.settingsAbout),
          ListTile(
            title: Text(l10n.version,
                style: AppTextTheme.body.copyWith(color: colors.onSurface)),
            trailing: Text('${AppInfo.version} (${AppInfo.buildNumber})',
                style: AppTextTheme.caption
                    .copyWith(color: colors.onSurfaceMuted)),
          ),
          _NavTile(
            label: l10n.githubRepo,
            icon: Icons.code,
            onTap: () {
              Clipboard.setData(const ClipboardData(text: AppInfo.githubUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(AppInfo.githubUrl)));
            },
          ),
          _NavTile(
            label: l10n.licenses,
            icon: Icons.description_outlined,
            onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appName,
                applicationVersion: AppInfo.version),
          ),
          _NavTile(
            label: l10n.backupExport,
            icon: Icons.upload_outlined,
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: jsonEncode(s.toJson())));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.settingsExported)));
            },
          ),
          _NavTile(
            label: l10n.backupImport,
            icon: Icons.download_outlined,
            onTap: () => _importDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _importDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        title: Text(l10n.backupImport,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: AppTextTheme.body.copyWith(color: colors.onSurface),
          decoration: InputDecoration(hintText: l10n.pasteBackupHint),
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
    if (text == null || text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      ref.read(settingsProvider.notifier).replaceAll(AppSettings.fromJson(map));
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsImported)));
    } catch (_) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.settingsImportFailed)));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SpacingTokens.xl, SpacingTokens.lg,
          SpacingTokens.xl, SpacingTokens.sm),
      child: Text(title,
          style: AppTextTheme.title.copyWith(color: colors.accent)),
    );
  }
}

class _Chips<T> extends StatelessWidget {
  const _Chips({
    required this.label,
    required this.values,
    required this.current,
    required this.labelFor,
    required this.onSelect,
  });

  final String label;
  final List<T> values;
  final T current;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SpacingTokens.xl, SpacingTokens.sm,
          SpacingTokens.lg, SpacingTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextTheme.body.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          Wrap(
            spacing: SpacingTokens.sm,
            runSpacing: SpacingTokens.xs,
            children: [
              for (final v in values)
                GestureDetector(
                  onTap: () => onSelect(v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.md,
                        vertical: SpacingTokens.xs),
                    decoration: BoxDecoration(
                      color: v == current
                          ? colors.accent
                          : colors.surfaceElevated,
                      borderRadius: RadiusTokens.brPill,
                    ),
                    child: Text(labelFor(v),
                        style: AppTextTheme.caption.copyWith(
                            color: v == current
                                ? colors.background
                                : colors.onSurfaceMuted)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
      title: Text(label,
          style: AppTextTheme.body.copyWith(color: colors.onSurface)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: AppTextTheme.body.copyWith(color: colors.onSurface)),
              const Spacer(),
              Text(display,
                  style: AppTextTheme.caption
                      .copyWith(color: colors.onSurfaceMuted)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TextTile extends StatelessWidget {
  const _TextTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.obscure = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SpacingTokens.xl, SpacingTokens.sm,
          SpacingTokens.xl, SpacingTokens.sm),
      child: TextFormField(
        initialValue: value,
        obscureText: obscure,
        style: AppTextTheme.body.copyWith(color: colors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: colors.surfaceElevated,
          border: const OutlineInputBorder(
              borderRadius: RadiusTokens.brSm, borderSide: BorderSide.none),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
      leading: Icon(icon, color: colors.onSurfaceMuted),
      title: Text(label,
          style: AppTextTheme.body.copyWith(color: colors.onSurface)),
      onTap: onTap,
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({required this.folders, required this.notifier});
  final List<String> folders;
  final SettingsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(SpacingTokens.xl, SpacingTokens.sm,
              SpacingTokens.sm, 0),
          child: Row(
            children: [
              Text(l10n.sourceFolders,
                  style: AppTextTheme.body.copyWith(color: colors.onSurface)),
              const Spacer(),
              IconButton(
                tooltip: l10n.addFolder,
                icon: Icon(Icons.create_new_folder_outlined,
                    color: colors.onSurface),
                onPressed: () => _addFolder(context),
              ),
            ],
          ),
        ),
        if (folders.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.sm),
            child: Text(l10n.noFolders,
                style: AppTextTheme.caption
                    .copyWith(color: colors.onSurfaceFaint)),
          )
        else
          for (final f in folders)
            ListTile(
              contentPadding: const EdgeInsets.only(
                  left: SpacingTokens.xl, right: SpacingTokens.md),
              dense: true,
              leading: Icon(Icons.folder_outlined, color: colors.onSurfaceMuted),
              title: Text(f,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.body.copyWith(color: colors.onSurface)),
              trailing: IconButton(
                icon: Icon(Icons.close, color: colors.onSurfaceFaint),
                onPressed: () => notifier.removeSourceFolder(f),
              ),
            ),
      ],
    );
  }

  Future<void> _addFolder(BuildContext context) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        title: Text(l10n.addFolder,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextTheme.body.copyWith(color: colors.onSurface),
          decoration: InputDecoration(hintText: l10n.folderHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
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
    if (path != null && path.trim().isNotEmpty) {
      notifier.addSourceFolder(path.trim());
    }
  }
}
