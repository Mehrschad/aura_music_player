import 'package:aura_music_player/app.dart';
import 'package:aura_music_player/core/constants/motion_tokens.dart';
import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/repositories/library_repository.dart';
import 'package:aura_music_player/presentation/pages/now_playing/now_playing_page.dart';
import 'package:aura_music_player/presentation/providers/library_providers.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:aura_music_player/presentation/widgets/player/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InstantRepo implements LibraryRepository {
  const _InstantRepo();
  @override
  Future<List<Song>> fetchSongs({bool forceRescan = false}) async => [
        Song(
          id: '1',
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          albumId: 'al1',
          artistId: 'ar1',
          duration: const Duration(seconds: 100),
          filePath: '/m/1.flac',
          dateAdded: DateTime(2024),
        ),
      ];
}

void main() {
  testWidgets('mini player expands to Now Playing; favourite and repeat work',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(const _InstantRepo()),
          audioControllerProvider
              .overrideWith((ref) => FakeAudioController(autoTick: false)),
        ],
        child: const AuraApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Start playback from the library; mini player appears (no breathing yet).
    await tester.tap(find.text('Test Song').first);
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsOneWidget);

    // Expand to Now Playing. Breathing animation repeats forever, so advance
    // with explicit pumps rather than pumpAndSettle.
    await tester.tap(find.byType(MiniPlayer));
    await tester.pump(); // start the route transition
    await tester.pump(MotionTokens.screen + const Duration(milliseconds: 80));

    expect(find.byType(NowPlayingPage), findsOneWidget);
    expect(find.text('Test Song'), findsWidgets);

    // Favourite toggles from outline to filled.
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // Cycling repeat twice reaches "repeat one".
    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pump();
    expect(find.byIcon(Icons.repeat_one), findsOneWidget);
  });
}
