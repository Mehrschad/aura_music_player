import 'package:aura_music_player/domain/models/bookmark.dart';
import 'package:aura_music_player/presentation/providers/bookmarks_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _makeContainer() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with empty list', () {
    final c = _makeContainer();
    expect(c.read(bookmarksProvider), isEmpty);
  });

  test('addBookmark adds an entry', () async {
    final c = _makeContainer();
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 'abc', positionMs: 5000, label: 'Chorus'),
        );
    expect(c.read(bookmarksProvider).length, 1);
    expect(c.read(bookmarksProvider).first.label, 'Chorus');
  });

  test('addBookmark deduplicates within 2 s', () async {
    final c = _makeContainer();
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 'abc', positionMs: 5000),
        );
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 'abc', positionMs: 5500), // within 2000 ms
        );
    expect(c.read(bookmarksProvider).length, 1);
  });

  test('addBookmark keeps distant bookmarks separate', () async {
    final c = _makeContainer();
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 'abc', positionMs: 5000),
        );
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 'abc', positionMs: 10000), // 5 s apart
        );
    expect(c.read(bookmarksProvider).length, 2);
  });

  test('removeBookmark removes the right entry', () async {
    final c = _makeContainer();
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 'abc', positionMs: 5000, label: 'A'),
        );
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 'abc', positionMs: 15000, label: 'B'),
        );
    await c.read(bookmarksProvider.notifier).removeBookmark('abc', 5000);
    final remaining = c.read(bookmarksProvider);
    expect(remaining.length, 1);
    expect(remaining.first.label, 'B');
  });

  test('songBookmarksProvider filters by songId and sorts', () async {
    final c = _makeContainer();
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 's1', positionMs: 10000),
        );
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 's2', positionMs: 3000),
        );
    await c.read(bookmarksProvider.notifier).addBookmark(
          const Bookmark(songId: 's1', positionMs: 4000),
        );
    final s1 = c.read(songBookmarksProvider('s1'));
    expect(s1.length, 2);
    expect(s1.first.positionMs, 4000); // sorted ascending
    expect(c.read(songBookmarksProvider('s2')).length, 1);
  });

  test('Bookmark.fromJson / toJson round-trips', () {
    const bm = Bookmark(songId: 'x', positionMs: 12345, label: 'Hello');
    final json = bm.toJson();
    final restored = Bookmark.fromJson(json);
    expect(restored.songId, bm.songId);
    expect(restored.positionMs, bm.positionMs);
    expect(restored.label, bm.label);
  });
}
