import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:aura_music_player/core/theme/glass_theme.dart';
import 'package:aura_music_player/domain/models/app_settings.dart';
import 'package:aura_music_player/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('copyWith changes only the given field', () {
      const s = AppSettings.defaults;
      final out = s.copyWith(themePref: ThemePref.light, gapless: false);
      expect(out.themePref, ThemePref.light);
      expect(out.gapless, isFalse);
      expect(out.dynamicColor, s.dynamicColor);
    });

    test('toJson/fromJson round-trips', () {
      const s = AppSettings(
        themePref: ThemePref.light,
        glassIntensity: GlassIntensity.strong,
        crossfadeSeconds: 6,
        replayGain: ReplayGainMode.album,
        locale: LocalePref.fa,
        sourceFolders: ['/music', '/sd'],
        textScale: 1.15,
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back.themePref, ThemePref.light);
      expect(back.glassIntensity, GlassIntensity.strong);
      expect(back.crossfadeSeconds, 6);
      expect(back.replayGain, ReplayGainMode.album);
      expect(back.locale, LocalePref.fa);
      expect(back.sourceFolders, ['/music', '/sd']);
      expect(back.textScale, 1.15);
    });

    test('fromJson falls back on unknown values', () {
      final back = AppSettings.fromJson({'themePref': 'bogus'});
      expect(back.themePref, AppSettings.defaults.themePref);
    });
  });

  group('mappers', () {
    test('theme mode + flavor', () {
      expect(themeModeFor(ThemePref.amoled), ThemeMode.dark);
      expect(themeModeFor(ThemePref.light), ThemeMode.light);
      expect(themeModeFor(ThemePref.system), ThemeMode.system);
      expect(darkFlavorFor(ThemePref.dark), DarkFlavor.standard);
      expect(darkFlavorFor(ThemePref.amoled), DarkFlavor.amoled);
    });

    test('locale', () {
      expect(localeFor(LocalePref.system), isNull);
      expect(localeFor(LocalePref.fa), const Locale('fa'));
    });
  });

  test('SettingsNotifier persists changes to the repository', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(settingsProvider.notifier).setDynamicColor(false);
    expect(c.read(settingsProvider).dynamicColor, isFalse);
    final saved = await c.read(settingsRepositoryProvider).load();
    expect(saved.dynamicColor, isFalse);
  });
}
