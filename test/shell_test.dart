import 'package:aura_music_player/app.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/repositories/library_repository.dart';
import 'package:aura_music_player/presentation/pages/library/library_page.dart';
import 'package:aura_music_player/presentation/providers/library_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/reduced_motion.dart';

/// Instant, deterministic repository so tests don't depend on the sample
/// repository's simulated scan latency.
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
          duration: const Duration(seconds: 200),
          filePath: '/m/1.flac',
          dateAdded: DateTime(2024),
        ),
      ];
}

Widget _app() => ProviderScope(
      overrides: [
        pastOnboarding(),
        libraryRepositoryProvider.overrideWithValue(const _InstantRepo()),
      ],
      child: const AuraApp(),
    );

void main() {
  testWidgets('Boots into Library, shows nav bar and a scanned song',
      (tester) async {
    useReducedMotion(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(LibraryPage), findsOneWidget);
    expect(find.text('Test Song'), findsOneWidget);

    // The nav bar is icon-only — each tab carries its name as a semantics
    // label rather than a visible Text, so assert on that.
    final semantics = tester.ensureSemantics();
    for (final tab in ['Library', 'Artists', 'Albums', 'Playlists', 'Search']) {
      expect(find.bySemanticsLabel(tab), findsWidgets, reason: 'nav tab $tab');
    }
    semantics.dispose();
  });

  testWidgets('Tapping a nav tab switches the active section', (tester) async {
    useReducedMotion(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Albums').first);
    await tester.pumpAndSettle();
    semantics.dispose();

    // The grouped album derived from the single test song.
    expect(find.text('Test Album'), findsOneWidget);
  });
}
