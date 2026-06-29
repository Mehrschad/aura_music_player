import 'package:aura_music_player/presentation/providers/ab_repeat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _makeContainer() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('initial state has no points', () {
    final c = _makeContainer();
    final ab = c.read(abRepeatProvider);
    expect(ab.hasA, isFalse);
    expect(ab.hasB, isFalse);
    expect(ab.isActive, isFalse);
  });

  test('setA stores point A for the song', () {
    final c = _makeContainer();
    c.read(abRepeatProvider.notifier).setA('s1', const Duration(seconds: 10));
    final ab = c.read(abRepeatProvider);
    expect(ab.hasA, isTrue);
    expect(ab.pointA, const Duration(seconds: 10));
    expect(ab.songId, 's1');
  });

  test('setB stores point B; isActive when both set', () {
    final c = _makeContainer();
    c.read(abRepeatProvider.notifier).setA('s1', const Duration(seconds: 10));
    c.read(abRepeatProvider.notifier).setB('s1', const Duration(seconds: 30));
    final ab = c.read(abRepeatProvider);
    expect(ab.isActive, isTrue);
    expect(ab.pointB, const Duration(seconds: 30));
  });

  test('shouldLoop returns true when position >= B', () {
    final c = _makeContainer();
    final notifier = c.read(abRepeatProvider.notifier);
    notifier.setA('s1', const Duration(seconds: 10));
    notifier.setB('s1', const Duration(seconds: 30));
    expect(notifier.shouldLoop('s1', const Duration(seconds: 30)), isTrue);
    expect(notifier.shouldLoop('s1', const Duration(seconds: 31)), isTrue);
    expect(notifier.shouldLoop('s1', const Duration(seconds: 29)), isFalse);
  });

  test('shouldLoop returns false for wrong song', () {
    final c = _makeContainer();
    final notifier = c.read(abRepeatProvider.notifier);
    notifier.setA('s1', const Duration(seconds: 10));
    notifier.setB('s1', const Duration(seconds: 30));
    expect(notifier.shouldLoop('s2', const Duration(seconds: 40)), isFalse);
  });

  test('setA on a different song clears B', () {
    final c = _makeContainer();
    final notifier = c.read(abRepeatProvider.notifier);
    notifier.setA('s1', const Duration(seconds: 5));
    notifier.setB('s1', const Duration(seconds: 20));
    notifier.setA('s2', const Duration(seconds: 0));
    final ab = c.read(abRepeatProvider);
    expect(ab.songId, 's2');
    expect(ab.hasB, isFalse);
  });

  test('clear resets all state', () {
    final c = _makeContainer();
    final notifier = c.read(abRepeatProvider.notifier);
    notifier.setA('s1', const Duration(seconds: 5));
    notifier.setB('s1', const Duration(seconds: 20));
    notifier.clear();
    final ab = c.read(abRepeatProvider);
    expect(ab.hasA, isFalse);
    expect(ab.hasB, isFalse);
    expect(ab.songId, isNull);
  });
}
