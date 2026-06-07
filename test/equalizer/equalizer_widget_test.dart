import 'package:aura_music_player/core/l10n/app_localizations.dart';
import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:aura_music_player/data/audio/visual_equalizer_controller.dart';
import 'package:aura_music_player/domain/audio/equalizer_presets.dart';
import 'package:aura_music_player/domain/models/equalizer.dart';
import 'package:aura_music_player/presentation/pages/equalizer/equalizer_page.dart';
import 'package:aura_music_player/presentation/providers/equalizer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a preset chip applies its gains', (tester) async {
    final eq = VisualEqualizerController();
    addTearDown(eq.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [equalizerControllerProvider.overrideWithValue(eq)],
        child: MaterialApp(
          theme: AppTheme.dark(flavor: DarkFlavor.amoled),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EqualizerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bass Boost'));
    await tester.pumpAndSettle();

    expect(eq.settings.gains, presetGains(EqPreset.bassBoost));
  });
}
