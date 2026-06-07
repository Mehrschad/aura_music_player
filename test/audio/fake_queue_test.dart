import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../library/_fixtures.dart';

void main() {
  late FakeAudioController c;
  setUp(() => c = FakeAudioController(autoTick: false));
  tearDown(() => c.dispose());

  final queue = [
    song(id: 'a'),
    song(id: 'b'),
    song(id: 'c'),
  ];

  test('playNext inserts directly after the current track', () async {
    await c.playQueue(queue); // current = a (0)
    await c.playNext(song(id: 'x'));
    expect(c.state.queue.map((s) => s.id), ['a', 'x', 'b', 'c']);
    expect(c.state.currentSong?.id, 'a');
  });

  test('addToQueue appends; on an empty queue it becomes current', () async {
    await c.addToQueue(song(id: 'z'));
    expect(c.state.currentSong?.id, 'z');
    await c.addToQueue(song(id: 'y'));
    expect(c.state.queue.map((s) => s.id), ['z', 'y']);
    expect(c.state.currentSong?.id, 'z');
  });

  test('removing a track before current shifts the index back', () async {
    await c.playQueue(queue, startIndex: 2); // current = c
    await c.removeFromQueue(0); // remove a
    expect(c.state.queue.map((s) => s.id), ['b', 'c']);
    expect(c.state.currentSong?.id, 'c');
  });

  test('removing the current track moves to the one that replaces it',
      () async {
    await c.playQueue(queue, startIndex: 1); // current = b
    await c.removeFromQueue(1);
    expect(c.state.queue.map((s) => s.id), ['a', 'c']);
    expect(c.state.currentSong?.id, 'c');
  });

  test('moveInQueue keeps the current track current', () async {
    await c.playQueue(queue, startIndex: 0); // current = a
    await c.moveInQueue(0, 2); // a moves to the end
    expect(c.state.queue.map((s) => s.id), ['b', 'c', 'a']);
    expect(c.state.currentSong?.id, 'a');
  });
}
