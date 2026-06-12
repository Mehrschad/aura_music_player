import 'package:aura_music_player/app.dart';
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
    // A small real-phone surface (360×690 logical) deliberately guards against
    // layout overflow: NowPlayingPage sizes its artwork from the remaining
    // height, so it must fit even compact screens. Overflow fails this test.
    await tester.binding.setSurfaceSize(const Size(360, 690));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    // Start playback from the library; mini player appears. The library row's
    // now-playing indicator animates forever once a track plays, so advance
    // with explicit pumps instead of pumpAndSettle from here on.
    await tester.tap(find.text('Test Song').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MiniPlayer), findsOneWidget);

    // Expand to Now Playing. Breathing animation repeats forever, so advance
    // with explicit pumps rather than pumpAndSettle. The open transition runs
    // ~460ms; pump comfortably past it so the page is settled and interactive.
    await tester.tap(find.byType(MiniPlayer));
    await tester.pump(); // start the route transition
    await tester.pump(const Duration(milliseconds: 560));

    expect(find.byType(NowPlayingPage), findsOneWidget);
    expect(find.text('Test Song'), findsWidgets);

    // Favourite toggles from outline to filled.
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // Cycling repeat twice reaches "repeat one".
    await tester.tap(find.byIcon(Icons.repeat_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.repeat_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
  });
}
