import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/domain/models/playback.dart';
import 'package:flutter_test/flutter_test.dart';

import '../library/_fixtures.dart';

void main() {
  late FakeAudioController c;

  setUp(() => c = FakeAudioController(autoTick: false));
  tearDown(() => c.dispose());

  final queue = [
    song(id: 'a', title: 'A', secs: 100),
    song(id: 'b', title: 'B', secs: 100),
    song(id: 'c', title: 'C', secs: 100),
  ];

  test('playQueue loads the start track and begins playing', () async {
    await c.playQueue(queue, startIndex: 1);
    expect(c.state.currentSong?.id, 'b');
    expect(c.state.playing, isTrue);
    expect(c.state.duration, const Duration(seconds: 100));
  });

  test('togglePlayPause flips the playing flag', () async {
    await c.playQueue(queue);
    await c.togglePlayPause();
    expect(c.state.playing, isFalse);
    await c.togglePlayPause();
    expect(c.state.playing, isTrue);
  });

  test('position advances while playing', () async {
    await c.playQueue(queue);
    c.advance(const Duration(seconds: 5));
    expect(c.position, const Duration(seconds: 5));
  });

  test('position does not advance while paused', () async {
    await c.playQueue(queue);
    await c.pause();
    c.advance(const Duration(seconds: 5));
    expect(c.position, Duration.zero);
  });

  test('seek clamps within the track bounds', () async {
    await c.playQueue(queue);
    await c.seek(const Duration(seconds: 250));
    expect(c.position, const Duration(seconds: 100));
    await c.seek(const Duration(seconds: -5));
    expect(c.position, Duration.zero);
  });

  test('skipToNext advances the index', () async {
    await c.playQueue(queue);
    await c.skipToNext();
    expect(c.state.currentSong?.id, 'b');
  });

  test('skipToPrevious restarts the track when past 3s, else steps back',
      () async {
    await c.playQueue(queue, startIndex: 1);
    c.advance(const Duration(seconds: 4));
    await c.skipToPrevious();
    // Past 3s -> restart same track.
    expect(c.state.currentSong?.id, 'b');
    expect(c.position, Duration.zero);

    await c.skipToPrevious();
    // Now at 0s -> step to previous track.
    expect(c.state.currentSong?.id, 'a');
  });

  test('repeat one restarts the same track on completion', () async {
    await c.playQueue(queue);
    await c.setRepeatMode(RepeatMode.one);
    c.advance(const Duration(seconds: 101));
    expect(c.state.currentSong?.id, 'a');
    expect(c.position, Duration.zero);
  });

  test('repeat all wraps from the last track to the first', () async {
    await c.playQueue(queue, startIndex: 2);
    await c.setRepeatMode(RepeatMode.all);
    await c.skipToNext();
    expect(c.state.currentSong?.id, 'a');
  });

  test('repeat off stops at the end of the queue', () async {
    await c.playQueue(queue, startIndex: 2);
    c.advance(const Duration(seconds: 101));
    expect(c.state.playing, isFalse);
    expect(c.state.status, PlaybackStatus.completed);
  });

  test('natural completion advances to the next track and keeps playing',
      () async {
    await c.playQueue(queue);
    c.advance(const Duration(seconds: 101));
    expect(c.state.currentSong?.id, 'b');
    expect(c.state.playing, isTrue);
  });

  test('setShuffle toggles the shuffle flag', () async {
    await c.playQueue(queue);
    await c.setShuffle(true);
    expect(c.state.shuffleEnabled, isTrue);
  });
}
