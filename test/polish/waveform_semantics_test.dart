import 'package:aura_music_player/core/l10n/app_localizations.dart';
import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:aura_music_player/presentation/widgets/waveform/waveform_scrubber.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('waveform scrubber exposes a seek slider to screen readers',
      (tester) async {
    final fake = FakeAudioController(autoTick: false);
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioControllerProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.dark(flavor: DarkFlavor.amoled),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: WaveformScrubber(
              duration: Duration(seconds: 200),
              accent: Color(0xFF8AB4F8),
              seed: 'x',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Seek bar'), findsOneWidget);
  });
}
