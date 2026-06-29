import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/repositories/library_repository.dart';
import 'package:aura_music_player/presentation/providers/library_providers.dart';
import 'package:aura_music_player/presentation/providers/multi_queue_controller.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:aura_music_player/presentation/providers/queue_registry_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements LibraryRepository {
  const _Repo();
  @override
  Future<List<Song>> fetchSongs({bool forceRescan = false}) async => [
        for (var i = 1; i <= 4; i++)
          Song(
            id: '$i',
            title: 'Song $i',
            artist: 'A',
            album: 'Al',
            albumId: 'al',
            artistId: 'ar',
            duration: const Duration(seconds: 100),
            filePath: '/m/$i.flac',
            dateAdded: DateTime(2024),
          ),
      ];
}

void main() {
  test('switching queues preserves each queue\'s remembered position',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(overrides: [
      libraryRepositoryProvider.overrideWithValue(const _Repo()),
      audioControllerProvider
          .overrideWith((ref) => FakeAudioController(autoTick: false)),
    ]);
    addTearDown(c.dispose);

    // Resolve the library so effectiveSongsProvider is populated.
    await c.read(songsProvider.future);

    final reg = c.read(queueRegistryProvider.notifier);
    final coord = c.read(multiQueueControllerProvider);
    final controller = c.read(audioControllerProvider) as FakeAudioController;

    final qA = reg.create('A', ['1', '2'])!;
    final qB = reg.create('B', ['3', '4'])!;

    // Make A live, jump to track 2 and seek 20 s in.
    await coord.switchTo(qA.id);
    expect(c.read(activeQueueIdProvider), qA.id);
    expect(controller.state.queue.map((s) => s.id).toList(), ['1', '2']);

    await controller.skipToIndex(1);
    await controller.seek(const Duration(seconds: 20));

    // Switch to B — this should snapshot A's cursor back into the registry.
    await coord.switchTo(qB.id);
    expect(c.read(activeQueueIdProvider), qB.id);
    expect(controller.state.queue.map((s) => s.id).toList(), ['3', '4']);

    final savedA = reg.byId(qA.id)!;
    expect(savedA.currentIndex, 1);
    expect(savedA.positionMs, 20000);

    // Switch back to A — engine resumes at the remembered track & position.
    await coord.switchTo(qA.id);
    expect(controller.state.currentIndex, 1);
    expect(controller.position, const Duration(seconds: 20));
    // Returning bumps A's play count to 2.
    expect(reg.byId(qA.id)!.playCount, 2);
  });
}
