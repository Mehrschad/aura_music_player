import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/constants/aurora_colors.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/backup/backup_bundle.dart';
import '../../../domain/models/app_settings.dart';
import '../../providers/backup_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/player_bar_inset.dart';
import '../equalizer/equalizer_page.dart';
import '../statistics/statistics_page.dart';
import 'lastfm_connect_page.dart';
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
        padding: EdgeInsets.fromLTRB(
          SpacingTokens.lg,
          0,
          SpacingTokens.lg,
          playerBarInset(context, miniPlayerVisible: ref.watch(hasMediaProvider)),
        ),
        children: [
          _GroupTitle(l10n.settingsAppearance),
          _CardGroup(children: [
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
                GlassIntensity.ultra => l10n.glassUltra,
              },
              onSelect: n.setGlassIntensity,
            ),
            _SwitchTile(
                label: l10n.dynamicColor,
                sub: l10n.dynamicColorSub,
                value: s.dynamicColor,
                onChanged: n.setDynamicColor),
            _Chips<VisualizerStyle>(
              label: 'Visualizer',
              values: VisualizerStyle.values,
              current: s.visualizerStyle,
              labelFor: (v) => switch (v) {
                VisualizerStyle.off => 'Off',
                VisualizerStyle.orbs => 'Orbs',
                VisualizerStyle.coverTwirl => 'Cover Twirl',
                VisualizerStyle.metaball => 'Metaball',
                VisualizerStyle.flowField => 'Flow Field',
              },
              onSelect: n.setVisualizerStyle,
            ),
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
                LocalePref.de => l10n.langDe,
              },
              onSelect: n.setLocale,
            ),
          ]),

          _GroupTitle(l10n.settingsAccessibility),
          _CardGroup(children: [
            _SwitchTile(
                label: l10n.reduceMotion,
                sub: l10n.reduceMotionSub,
                value: s.reduceMotion,
                onChanged: n.setReduceMotion),
          ]),

          _GroupTitle(l10n.settingsLibrary),
          _CardGroup(children: [
            _FolderList(folders: s.sourceFolders, notifier: n),
            _SwitchTile(
                label: l10n.scanOnStartup,
                value: s.scanOnStartup,
                onChanged: n.setScanOnStartup),
            _SwitchTile(
                label: l10n.showHidden,
                value: s.showHidden,
                onChanged: n.setShowHidden),
            _SwitchTile(
                label: l10n.hideDotFolders,
                value: s.hideDotFolders,
                onChanged: n.setHideDotFolders),
            _SliderTile(
              label: l10n.minTrackLength,
              value: s.minTrackSeconds.toDouble(),
              min: 0,
              max: 60,
              divisions: 12,
              display: '${s.minTrackSeconds}s',
              onChanged: (v) => n.setMinTrackSeconds(v.round()),
            ),
            _ExcludedFolderList(folders: s.excludedFolders, notifier: n),
            _SwitchTile(
                label: l10n.allowSdCardEdit,
                value: s.allowSdCardEdit,
                onChanged: n.setAllowSdCardEdit),
            _NavTile(
              label: l10n.rescanNow,
              icon: Icons.refresh,
              onTap: () => ref.read(rescanProvider)(),
            ),
          ]),

          _GroupTitle(l10n.settingsPlayback),
          _CardGroup(children: [
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
                label: l10n.gapless,
                value: s.gapless,
                onChanged: n.setGapless),
            _SwitchTile(
                label: l10n.speedMemory,
                value: s.speedMemory,
                onChanged: n.setSpeedMemory),
            _SwitchTile(
                label: l10n.skipSilence,
                value: s.skipSilence,
                onChanged: n.setSkipSilence),
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
          ]),

          _GroupTitle(l10n.settingsEqualizer),
          _CardGroup(children: [
            _NavTile(
              label: l10n.manageEqualizer,
              icon: Icons.graphic_eq,
              onTap: () => openEqualizer(context),
            ),
          ]),

          _GroupTitle(l10n.listeningStats),
          _CardGroup(children: [
            _NavTile(
              label: l10n.listeningStats,
              icon: Icons.bar_chart_rounded,
              onTap: () => openStatistics(context),
            ),
          ]),

          _GroupTitle(l10n.settingsLyrics),
          _CardGroup(children: [
            _SwitchTile(
                label: l10n.lyricsAutoFetch,
                sub: l10n.lyricsAutoFetchSub,
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
          ]),

          _GroupTitle(l10n.settingsIntegrations),
          _CardGroup(children: [
            _NavTile(
              label: l10n.homeWidgets,
              icon: Icons.widgets_outlined,
              onTap: () => openWidgetPreview(context),
            ),
            if (s.lastFmSessionKey.isNotEmpty)
              _NavTile(
                label: l10n.lastFmConnectedAs(s.lastFmUsername),
                icon: Icons.check_circle_outline,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const LastFmConnectPage())),
              )
            else
              _NavTile(
                label: l10n.lastFmConnect,
                icon: Icons.link,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const LastFmConnectPage())),
              ),
            _SwitchTile(
                label: l10n.lastFm,
                value: s.lastFmEnabled,
                onChanged: n.setLastFm),
            _SwitchTile(
                label: l10n.androidAuto,
                sub: l10n.androidAutoSub,
                value: s.androidAuto,
                onChanged: n.setAndroidAuto),
          ]),

          _GroupTitle(l10n.backupRestore),
          _CardGroup(children: [
            _NavTile(
              label: l10n.backupExportAll,
              icon: Icons.cloud_upload_outlined,
              onTap: () {
                final bundle =
                    ref.read(backupCoordinatorProvider).createBundle();
                Clipboard.setData(
                    ClipboardData(text: jsonEncode(bundle.toJson())));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.backupExportedAll)));
              },
            ),
            _NavTile(
              label: l10n.backupImportAll,
              icon: Icons.cloud_download_outlined,
              onTap: () => _fullRestoreDialog(context, ref),
            ),
          ]),

          _GroupTitle(l10n.settingsAbout),
          _CardGroup(children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
              leading: Icon(Icons.info_outline, color: colors.onSurfaceMuted),
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
                Clipboard.setData(
                    const ClipboardData(text: AppInfo.githubUrl));
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
          ]),
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

  Future<void> _fullRestoreDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        title: Text(l10n.backupImportAll,
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
      final bundle = BackupBundle.fromJson(map);
      ref.read(backupCoordinatorProvider).restore(bundle);
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupImportedAll)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupImportFailed)));
    }
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, SpacingTokens.xxl, 4, SpacingTokens.sm),
      child: Text(
        title.toUpperCase(),
        style: AppTextTheme.caption.copyWith(
          color: AuroraColors.c2,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: RadiusTokens.brMd,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brMd,
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            children.first,
            for (var i = 1; i < children.length; i++) ...[
              Divider(height: 1, thickness: 0.5, color: colors.divider),
              children[i],
            ],
          ],
        ),
      ),
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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(v);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.md,
                        vertical: SpacingTokens.sm),
                    decoration: BoxDecoration(
                      // Selected chips use the aurora-2 accent per the DS.
                      color: v == current
                          ? AuroraColors.c2
                          : colors.surface,
                      borderRadius: RadiusTokens.brPill,
                      border: Border.all(
                          color: v == current
                              ? AuroraColors.c2
                              : colors.divider),
                    ),
                    child: Text(labelFor(v),
                        style: AppTextTheme.caption.copyWith(
                            color: v == current
                                ? AuroraColors.onAurora
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
      {required this.label,
      required this.value,
      required this.onChanged,
      this.sub});
  final String label;
  final String? sub;
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
      subtitle: sub == null
          ? null
          : Text(sub!,
              style: AppTextTheme.caption
                  .copyWith(color: colors.onSurfaceFaint)),
      value: value,
      // Switch tracks/thumbs use the aurora-2 accent per the DS.
      activeColor: AuroraColors.onAurora,
      activeTrackColor: AuroraColors.c2,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
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
          // Slider track/thumb use the aurora-2 accent per the DS.
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AuroraColors.c2,
              thumbColor: AuroraColors.c2,
              inactiveTrackColor: colors.divider,
              overlayColor: AuroraColors.c2.withOpacity(0.18),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
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
      {required this.label,
      required this.icon,
      required this.onTap,
      this.sub,
      this.trailing});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? sub;

  /// Optional trailing value (e.g. version string). When set the chevron is
  /// replaced by this text, matching the DS RowNav trailing variant.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
      leading: Icon(icon, color: colors.onSurfaceMuted),
      title: Text(label,
          style: AppTextTheme.body.copyWith(color: colors.onSurface)),
      subtitle: sub == null
          ? null
          : Text(sub!,
              style: AppTextTheme.caption
                  .copyWith(color: colors.onSurfaceFaint)),
      trailing: trailing != null
          ? Text(trailing!,
              style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted))
          : Icon(Icons.chevron_right, color: colors.onSurfaceFaint),
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
                tooltip: l10n.delete,
                icon: Icon(Icons.close, color: colors.onSurfaceFaint),
                onPressed: () => notifier.removeSourceFolder(f),
              ),
            ),
      ],
    );
  }

  Future<void> _addFolder(BuildContext context) async {
    String? path;
    try {
      path = await FilePicker.platform.getDirectoryPath();
    } catch (_) {
      path = null;
    }

    if (path == null && context.mounted) {
      path = await _showManualDialog(context);
    }

    if (path != null && path.trim().isNotEmpty) {
      notifier.addSourceFolder(path.trim());
    }
  }

  Future<String?> _showManualDialog(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return showDialog<String>(
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(l10n.save)),
        ],
      ),
    );
  }
}

class _ExcludedFolderList extends StatelessWidget {
  const _ExcludedFolderList({required this.folders, required this.notifier});
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
          padding: const EdgeInsets.fromLTRB(
              SpacingTokens.xl, SpacingTokens.sm, SpacingTokens.sm, 0),
          child: Row(
            children: [
              Text(l10n.excludedFolders,
                  style: AppTextTheme.body.copyWith(color: colors.onSurface)),
              const Spacer(),
              IconButton(
                tooltip: l10n.addFolder,
                icon: Icon(Icons.add, color: colors.onSurface),
                onPressed: () => _add(context),
              ),
            ],
          ),
        ),
        if (folders.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.sm),
            child: Text(l10n.noExcludedFolders,
                style: AppTextTheme.caption
                    .copyWith(color: colors.onSurfaceFaint)),
          )
        else
          for (final f in folders)
            ListTile(
              contentPadding: const EdgeInsets.only(
                  left: SpacingTokens.xl, right: SpacingTokens.md),
              dense: true,
              leading: Icon(Icons.block, color: colors.onSurfaceMuted),
              title: Text(f,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.body.copyWith(color: colors.onSurface)),
              trailing: IconButton(
                tooltip: l10n.delete,
                icon: Icon(Icons.close, color: colors.onSurfaceFaint),
                onPressed: () => notifier.removeExcludedFolder(f),
              ),
            ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    String? path;
    try {
      path = await FilePicker.platform.getDirectoryPath();
    } catch (_) {
      path = null;
    }
    if (path == null && context.mounted) {
      final l10n = AppLocalizations.of(context);
      final colors = context.colors;
      final controller = TextEditingController();
      path = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(l10n.excludedFolders,
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
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel)),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text(l10n.save)),
          ],
        ),
      );
    }
    if (path != null && path.trim().isNotEmpty) {
      notifier.addExcludedFolder(path.trim());
    }
  }
}
