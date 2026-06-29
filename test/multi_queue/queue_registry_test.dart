import 'package:aura_music_player/domain/models/named_queue.dart';
import 'package:aura_music_player/domain/models/playback.dart';
import 'package:aura_music_player/presentation/providers/queue_registry_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _c() {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('QueueRegistry CRUD', () {
    test('create adds a queue at the front', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      reg.create('A', ['1', '2']);
      reg.create('B', ['3']);
      final list = c.read(queueRegistryProvider);
      expect(list.length, 2);
      expect(list.first.name, 'B');
      expect(list.last.songIds, ['1', '2']);
    });

    test('rename / recolor / setKind mutate in place', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      final q = reg.create('A', ['1'])!;
      reg.rename(q.id, 'Renamed');
      reg.recolor(q.id, 5);
      reg.setKind(q.id, QueueKind.audiobook);
      final got = reg.byId(q.id)!;
      expect(got.name, 'Renamed');
      expect(got.colorIndex, 5);
      expect(got.kind, QueueKind.audiobook);
    });

    test('delete removes by id', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      final q = reg.create('A', ['1'])!;
      reg.delete(q.id);
      expect(c.read(queueRegistryProvider), isEmpty);
    });

    test('duplicate inserts a copy right after the source', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      final q = reg.create('A', ['1', '2'])!;
      final dup = reg.duplicate(q.id)!;
      final list = c.read(queueRegistryProvider);
      expect(list.length, 2);
      expect(dup.name, 'A copy');
      expect(dup.songIds, ['1', '2']);
      expect(dup.id, isNot(q.id));
      expect(list.indexOf(dup), list.indexOf(q) + 1);
    });

    test('reorder moves a queue', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      reg.create('A', ['1']); // index 1 after next insert
      reg.create('B', ['2']); // index 0
      reg.reorder(0, 1);
      expect(c.read(queueRegistryProvider).map((q) => q.name).toList(),
          ['A', 'B']);
    });

    test('reorderSongs moves a track within a queue', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      final q = reg.create('A', ['1', '2', '3'])!;
      reg.reorderSongs(q.id, 0, 2);
      expect(reg.byId(q.id)!.songIds, ['2', '3', '1']);
    });
  });

  group('Snapshot / position preservation', () {
    test('updateSnapshot writes the live cursor back', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      final q = reg.create('A', ['1', '2', '3'])!;
      reg.updateSnapshot(q.id,
          currentIndex: 2,
          positionMs: 45000,
          shuffle: true,
          repeatMode: RepeatMode.all);
      final got = reg.byId(q.id)!;
      expect(got.currentIndex, 2);
      expect(got.positionMs, 45000);
      expect(got.shuffle, isTrue);
      expect(got.repeatMode, RepeatMode.all);
    });

    test('markPlayed bumps play count', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      final q = reg.create('A', ['1'])!;
      reg.markPlayed(q.id);
      reg.markPlayed(q.id);
      expect(reg.byId(q.id)!.playCount, 2);
    });
  });

  group('Cap enforcement', () {
    test('create no-ops past 20 queues', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      for (var i = 0; i < QueueRegistry.maxQueues; i++) {
        expect(reg.create('Q$i', ['$i']), isNotNull);
      }
      expect(c.read(queueRegistryProvider).length, 20);
      expect(reg.isFull, isTrue);
      expect(reg.create('overflow', ['x']), isNull);
      expect(c.read(queueRegistryProvider).length, 20);
    });

    test('duplicate no-ops at the cap', () {
      final c = _c();
      final reg = c.read(queueRegistryProvider.notifier);
      for (var i = 0; i < QueueRegistry.maxQueues; i++) {
        reg.create('Q$i', ['$i']);
      }
      expect(c.read(queueRegistryProvider).length, 20);
      final first = c.read(queueRegistryProvider).first;
      expect(reg.duplicate(first.id), isNull);
      expect(c.read(queueRegistryProvider).length, 20);
    });
  });

  test('NamedQueue toJson / fromJson round-trips', () {
    final q = NamedQueue(
      id: 'q1',
      name: 'Test',
      songIds: const ['1', '2'],
      currentIndex: 1,
      shuffle: true,
      repeatMode: RepeatMode.one,
      positionMs: 1234,
      colorIndex: 7,
      kind: QueueKind.podcast,
      playCount: 3,
      lastTouched: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final r = NamedQueue.fromJson(q.toJson());
    expect(r.id, q.id);
    expect(r.songIds, q.songIds);
    expect(r.currentIndex, 1);
    expect(r.shuffle, isTrue);
    expect(r.repeatMode, RepeatMode.one);
    expect(r.colorIndex, 7);
    expect(r.kind, QueueKind.podcast);
    expect(r.playCount, 3);
  });
}
