import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/domain/lyrics/lrc_parser.dart';
import 'package:aura_music_player/domain/models/lyrics.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/presentation/pages/lyrics/sync_editor_page.dart';
import 'package:aura_music_player/presentation/providers/lyrics_providers.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:aura_music_player/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song() => Song(
      id: 's1',
      title: 'T',
      artist: 'A',
      album: 'Al',
      albumId: 'a1',
      artistId: 'ar1',
      duration: const Duration(seconds: 252),
      filePath: '/m/s1.flac',
      dateAdded: DateTime(2024),
    );

void main() {
  testWidgets('tap records a timestamp visible in the tune list',
      (tester) async {
    final fake = FakeAudioController(autoTick: false);
    addTearDown(fake.dispose);
    await fake.playQueue([_song()]);
    await fake.pause();
    await fake.seek(const Duration(seconds: 5));

    final Lyrics plain = parsePlainLyrics('line one\nline two\nline three');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioControllerProvider.overrideWithValue(fake),
          currentLyricsProvider.overrideWith((ref) async => plain),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(flavor: DarkFlavor.amoled),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SyncEditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First line is the active tap target.
    expect(find.text('line one'), findsOneWidget);

    // Tap to stamp at 5s.
    await tester.tap(find.text('line one'));
    await tester.pump();

    // Switch to Tune and confirm the recorded timestamp shows.
    await tester.tap(find.text('Tune'));
    await tester.pumpAndSettle();
    expect(find.text('00:05.00'), findsOneWidget);
  });
}
