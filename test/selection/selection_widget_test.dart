import 'package:aura_music_player/app.dart';
import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/repositories/library_repository.dart';
import 'package:aura_music_player/presentation/providers/favorites_providers.dart';
import 'package:aura_music_player/presentation/providers/library_providers.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/reduced_motion.dart';

class _ThreeSongRepo implements LibraryRepository {
  const _ThreeSongRepo();
  @override
  Future<List<Song>> fetchSongs({bool forceRescan = false}) async => [
        for (var i = 0; i < 3; i++)
          Song(
            id: '${i + 1}',
            title: 'Song ${String.fromCharCode(65 + i)}', // Song A/B/C
            artist: 'Artist',
            album: 'Album',
            albumId: 'al1',
            artistId: 'ar1',
            duration: const Duration(seconds: 100),
            filePath: '/m/${i + 1}.flac',
            dateAdded: DateTime(2024),
          ),
      ];
}

ProviderContainer? _container;

Widget _app() {
  return ProviderScope(
    overrides: [
      pastOnboarding(),
      libraryRepositoryProvider.overrideWithValue(const _ThreeSongRepo()),
      audioControllerProvider
          .overrideWith((ref) => FakeAudioController(autoTick: false)),
    ],
    child: Consumer(builder: (context, ref, _) {
      // Capture a container handle to assert provider state post-action.
      _container = ProviderScope.containerOf(context, listen: false);
      return const AuraApp();
    }),
  );
}

void main() {
  testWidgets('long-press enters selection; select-all then favorite all',
      (tester) async {
    useReducedMotion(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Song A'), findsOneWidget);

    // Long-press a row → selection mode with one picked.
    await tester.longPress(find.text('Song A'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Select all → 3 selected.
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);

    // Open bulk actions and favourite everything.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to favorites'));
    await tester.pumpAndSettle();

    final favorites = _container!.read(favoritesProvider);
    expect(favorites, {'1', '2', '3'});

    // Selection cleared → section header is back.
    expect(find.text('3 selected'), findsNothing);
  });

  testWidgets('bulk hide removes tracks from the library', (tester) async {
    useReducedMotion(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Song A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // The actions sheet is a lazy ListView, so the entry may not be built yet.
    // Scope the scroll to the sheet's own list — the library's horizontal
    // rails underneath are Scrollables too, and dragging one of those misses.
    final hide = find.text('Hide from library');
    await tester.scrollUntilVisible(
      hide,
      80,
      scrollable: find.descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(hide);
    await tester.pumpAndSettle();

    // All three hidden → the library shows its empty state. The shell builds
    // every tab, so Artists and Albums show it too.
    expect(find.text('Song A'), findsNothing);
    expect(find.text('No music found'), findsWidgets);
  });
}
