import 'package:aura_music_player/presentation/providers/recent_searches_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Persistence is best-effort; mock prefs so _load/_save stay quiet.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('record adds to front', () {
    final n = RecentSearchesNotifier();
    n.record('one');
    n.record('two');
    expect(n.state.first, 'two');
    expect(n.state, ['two', 'one']);
  });

  test('recording an existing term (different case) moves it to front', () {
    final n = RecentSearchesNotifier();
    n.record('Beatles');
    n.record('Queen');
    n.record('beatles');
    expect(n.state, ['beatles', 'Queen']);
  });

  test('caps at 10 entries, newest first', () {
    final n = RecentSearchesNotifier();
    for (var i = 0; i < 12; i++) {
      n.record('term$i');
    }
    expect(n.state.length, 10);
    expect(n.state.first, 'term11');
    expect(n.state.last, 'term2');
  });

  test('remove drops a single term', () {
    final n = RecentSearchesNotifier();
    n.record('a');
    n.record('b');
    n.remove('a');
    expect(n.state, ['b']);
  });

  test('clear empties the list', () {
    final n = RecentSearchesNotifier();
    n.record('a');
    n.clear();
    expect(n.state, isEmpty);
  });
}
