import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_theme.dart';
import '../../data/repositories/in_memory_settings_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => InMemorySettingsRepository());

/// The single source of truth for preferences. Setters persist via the
/// repository. On device, hydrate the initial value from `repo.load()` before
/// `runApp`; the in-memory store already starts at defaults.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._repo, AppSettings initial) : super(initial);

  final SettingsRepository _repo;

  void _update(AppSettings next) {
    state = next;
    _repo.save(next);
  }

  void setTheme(ThemePref v) => _update(state.copyWith(themePref: v));
  void setGlassIntensity(GlassIntensity v) =>
      _update(state.copyWith(glassIntensity: v));
  void setDynamicColor(bool v) => _update(state.copyWith(dynamicColor: v));
  void setTextScale(double v) => _update(state.copyWith(textScale: v));
  void setDensity(DisplayDensity v) => _update(state.copyWith(density: v));
  void setLocale(LocalePref v) => _update(state.copyWith(locale: v));

  void addSourceFolder(String path) =>
      _update(state.copyWith(sourceFolders: [...state.sourceFolders, path]));
  void removeSourceFolder(String path) => _update(state.copyWith(
      sourceFolders:
          state.sourceFolders.where((p) => p != path).toList()));
  void setScanOnStartup(bool v) => _update(state.copyWith(scanOnStartup: v));
  void setShowHidden(bool v) => _update(state.copyWith(showHidden: v));

  void addExcludedFolder(String path) {
    if (state.excludedFolders.contains(path)) return;
    _update(state.copyWith(excludedFolders: [...state.excludedFolders, path]));
  }

  void removeExcludedFolder(String path) => _update(state.copyWith(
      excludedFolders:
          state.excludedFolders.where((p) => p != path).toList()));
  void setHideDotFolders(bool v) =>
      _update(state.copyWith(hideDotFolders: v));
  void setMinTrackSeconds(int v) =>
      _update(state.copyWith(minTrackSeconds: v));
  void setAllowSdCardEdit(bool v) =>
      _update(state.copyWith(allowSdCardEdit: v));

  void setCrossfade(double seconds) =>
      _update(state.copyWith(crossfadeSeconds: seconds));
  void setReplayGain(ReplayGainMode v) =>
      _update(state.copyWith(replayGain: v));
  void setGapless(bool v) => _update(state.copyWith(gapless: v));
  void setSpeedMemory(bool v) => _update(state.copyWith(speedMemory: v));
  void setSkipSilence(bool v) => _update(state.copyWith(skipSilence: v));
  void setPitchSemitones(double v) => _update(state.copyWith(pitchSemitones: v));
  void setInterruption(InterruptionBehavior v) =>
      _update(state.copyWith(interruption: v));

  void setLyricsAutoFetch(bool v) =>
      _update(state.copyWith(lyricsAutoFetch: v));
  void setLyricsDefaultLanguage(String v) =>
      _update(state.copyWith(lyricsDefaultLanguage: v));
  void setGeniusApiKey(String v) => _update(state.copyWith(geniusApiKey: v));

  void setLastFm(bool v) => _update(state.copyWith(lastFmEnabled: v));
  void setAndroidAuto(bool v) => _update(state.copyWith(androidAuto: v));

  /// Replaces the whole settings object (settings backup import).
  void replaceAll(AppSettings v) => _update(v);
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo, AppSettings.defaults);
});

// ── Pure mappers (used by the app root) ────────────────────────────────────

ThemeMode themeModeFor(ThemePref p) => switch (p) {
      ThemePref.system => ThemeMode.system,
      ThemePref.light => ThemeMode.light,
      ThemePref.dark || ThemePref.amoled => ThemeMode.dark,
    };

DarkFlavor darkFlavorFor(ThemePref p) =>
    p == ThemePref.dark ? DarkFlavor.standard : DarkFlavor.amoled;

Locale? localeFor(LocalePref p) => switch (p) {
      LocalePref.system => null,
      LocalePref.en => const Locale('en'),
      LocalePref.fa => const Locale('fa'),
      LocalePref.ar => const Locale('ar'),
      LocalePref.de => const Locale('de'),
    };

VisualDensity visualDensityFor(DisplayDensity d) => switch (d) {
      DisplayDensity.comfortable => VisualDensity.comfortable,
      DisplayDensity.standard => VisualDensity.standard,
      DisplayDensity.compact => VisualDensity.compact,
    };
