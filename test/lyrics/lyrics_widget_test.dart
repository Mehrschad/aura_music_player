import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/presentation/pages/lyrics/lyrics_page.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_music_player/core/l10n/app_localizations.dart';

Song _s1() => Song(
      id: 's1',
      title: 'Aurora Skyline',
      artist: 'Marlowe',
      album: 'Northern Glass',
      albumId: 'a1',
      artistId: 'ar1',
      duration: const Duration(seconds: 252),
      filePath: '/m/s1.flac',
      dateAdded: DateTime(2024),
      hasLyrics: true,
    );

void main() {
  testWidgets('lyrics view shows bundled lines for the current track',
      (tester) async {
    final fake = FakeAudioController(autoTick: false);
    addTearDown(fake.dispose);
    await fake.playQueue([_s1()]);
    await fake.pause();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioControllerProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.dark(flavor: DarkFlavor.amoled),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LyricsPage(),
        ),
      ),
    );
    // LyricsPage contains an infinite ambient animation so pumpAndSettle would
    // time out. Pump enough for the async lyrics FutureProvider to resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Aurora skyline'), findsOneWidget);
    expect(find.text('Light spills over the line'), findsOneWidget);
  });
}
