import 'package:aura_music_player/core/l10n/app_localizations.dart';
import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:aura_music_player/presentation/widgets/waveform/waveform_scrubber.dart';
import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song() => Song(
      id: 's1',
      title: 'T',
      artist: 'A',
      album: 'Al',
      albumId: 'al1',
      artistId: 'ar1',
      duration: const Duration(seconds: 100),
      filePath: '/m/1.flac',
      dateAdded: DateTime(2024),
    );

void main() {
  testWidgets('tapping the waveform seeks to the corresponding fraction',
      (tester) async {
    final fake = FakeAudioController(autoTick: false);
    addTearDown(fake.dispose);
    await fake.playQueue([_song()]);
    await fake.pause();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioControllerProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.dark(flavor: DarkFlavor.amoled),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WaveformScrubber(
                  duration: const Duration(seconds: 100),
                  accent: const Color(0xFF8E8E93),
                  seed: 'al1',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = find.byKey(const Key('waveform_gesture'));
    final topLeft = tester.getTopLeft(gesture);
    final size = tester.getSize(gesture);

    // Tap at 75% of the width.
    await tester.tapAt(Offset(topLeft.dx + size.width * 0.75, topLeft.dy + size.height / 2));
    await tester.pump();

    // ~75s into a 100s track (allow a bar's worth of rounding).
    expect(fake.position.inSeconds, closeTo(75, 2));
  });
}
