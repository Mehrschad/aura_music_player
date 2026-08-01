import 'package:aura_music_player/app.dart';
import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/repositories/library_repository.dart';
import 'package:aura_music_player/presentation/providers/library_providers.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:aura_music_player/presentation/widgets/player/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/reduced_motion.dart';

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
  testWidgets('mini player is hidden until a song is played, then appears',
      (tester) async {
    useReducedMotion(tester);
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

    // The MiniPlayer widget is mounted but shows nothing yet.
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    // Tap the song row to start playback. Once a track is playing, the
    // now-playing row indicator animates forever, so advance with explicit
    // pumps instead of pumpAndSettle.
    await tester.tap(find.text('Test Song').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // The mini player now shows the track and a pause control (it's playing).
    expect(find.text('Test Song'), findsWidgets);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Toggling pause swaps the icon to play.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
