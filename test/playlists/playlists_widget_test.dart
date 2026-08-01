import 'package:aura_music_player/app.dart';
import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/data/repositories/in_memory_playlist_repository.dart';
import 'package:aura_music_player/data/repositories/sample_library_repository.dart';
import 'package:aura_music_player/presentation/pages/playlists/playlist_detail_page.dart';
import 'package:aura_music_player/presentation/providers/library_providers.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:aura_music_player/presentation/providers/playlist_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/reduced_motion.dart';

void main() {
  testWidgets('Playlists tab shows the seeded playlist and opens its detail',
      (tester) async {
    useReducedMotion(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pastOnboarding(),
          libraryRepositoryProvider
              .overrideWithValue(const SampleLibraryRepository()),
          // The app persists playlists to SharedPreferences, which is empty
          // under test. This test is about the seeded playlist, so pin the
          // in-memory repository that carries it.
          playlistRepositoryProvider
              .overrideWith((ref) => InMemoryPlaylistRepository()),
          audioControllerProvider
              .overrideWith((ref) => FakeAudioController(autoTick: false)),
        ],
        child: const AuraApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to the Playlists tab.
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    // Auto playlists and the seeded user playlist are present.
    expect(find.text('Recently added'), findsOneWidget);
    expect(find.text('Evening Wind-down'), findsOneWidget);

    // Open the seeded playlist; its detail lists a known sample track.
    await tester.tap(find.text('Evening Wind-down'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistDetailPage), findsOneWidget);
    expect(find.text('Adagio in Grey'), findsOneWidget); // sample song s10
  });
}
