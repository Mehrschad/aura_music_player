import 'package:aura_music_player/domain/models/playback.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/widgets/home_widget_state.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song() => Song(
      id: 's1',
      title: 'Title',
      artist: 'Artist',
      album: 'Al',
      albumId: 'al1',
      artistId: 'ar1',
      duration: const Duration(seconds: 200),
      filePath: '/m/s1',
      dateAdded: DateTime(2024),
      hasArtwork: true,
    );

void main() {
  test('empty state when nothing playing', () {
    final s = homeWidgetStateFrom(
      song: null,
      state: const PlaybackState(queue: []),
      position: Duration.zero,
    );
    expect(s.hasMedia, isFalse);
    expect(s, HomeWidgetState.empty);
  });

  test('maps song + playback into widget state with progress', () {
    final s = homeWidgetStateFrom(
      song: _song(),
      state: const PlaybackState(
          queue: [], playing: true, shuffleEnabled: true, repeatMode: RepeatMode.all),
      position: const Duration(seconds: 50),
    );
    expect(s.hasMedia, isTrue);
    expect(s.title, 'Title');
    expect(s.playing, isTrue);
    expect(s.shuffle, isTrue);
    expect(s.repeat, RepeatMode.all);
    expect(s.progress, closeTo(0.25, 0.001));
  });

  test('toWidgetData serialises primitives', () {
    final data = homeWidgetStateFrom(
      song: _song(),
      state: const PlaybackState(queue: [], playing: false),
      position: const Duration(seconds: 100),
    ).toWidgetData();
    expect(data['has_media'], 'true');
    expect(data['title'], 'Title');
    expect(data['playing'], 'false');
    expect(data['progress'], '0.5000');
    expect(data['repeat'], 'off');
  });
}
