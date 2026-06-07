import 'package:aura_music_player/domain/lyrics/sync_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timestamp format/parse', () {
    test('formats centiseconds', () {
      expect(formatLrcTimestamp(const Duration(minutes: 1, seconds: 2, milliseconds: 340)),
          '01:02.34');
      expect(formatLrcTimestamp(const Duration(seconds: 5)), '00:05.00');
    });
    test('parses mm:ss.xx and mm:ss; rejects garbage', () {
      expect(parseLrcTimestamp('00:05.00'), const Duration(seconds: 5));
      expect(parseLrcTimestamp('1:02'), const Duration(minutes: 1, seconds: 2));
      expect(parseLrcTimestamp('nope'), isNull);
      expect(parseLrcTimestamp('00:75.00'), isNull);
    });
  });

  group('SyncDraft', () {
    SyncDraft draft() => SyncDraft.fromTexts(['one', '', 'two', 'three']);

    test('fromTexts drops blank lines', () {
      expect(draft().entries.map((e) => e.text), ['one', 'two', 'three']);
    });

    test('stamp records time and advances the cursor', () {
      final d = draft().stamp(const Duration(seconds: 1));
      expect(d.cursor, 1);
      expect(d.entries[0].time, const Duration(seconds: 1));
      expect(d.entries[1].time, isNull);
    });

    test('undo clears the last stamp and steps back', () {
      final d = draft().stamp(const Duration(seconds: 1)).undo();
      expect(d.cursor, 0);
      expect(d.entries[0].time, isNull);
    });

    test('shiftLine clamps at zero', () {
      final d = draft().setTime(0, const Duration(milliseconds: 300));
      final shifted = d.shiftLine(0, const Duration(milliseconds: -500));
      expect(shifted.entries[0].time, Duration.zero);
    });

    test('shiftAll moves every stamped line', () {
      final d = draft()
          .setTime(0, const Duration(seconds: 1))
          .setTime(1, const Duration(seconds: 2));
      final shifted = d.shiftAll(const Duration(milliseconds: 500));
      expect(shifted.entries[0].time, const Duration(milliseconds: 1500));
      expect(shifted.entries[1].time, const Duration(milliseconds: 2500));
      expect(shifted.entries[2].time, isNull);
    });

    test('toLrc emits stamped lines in time order', () {
      final d = draft()
          .setTime(2, const Duration(seconds: 1))
          .setTime(0, const Duration(seconds: 3));
      expect(d.toLrc(), '[00:01.00]three\n[00:03.00]one\n');
    });

    test('isComplete only when every line is stamped', () {
      var d = draft();
      expect(d.isComplete, isFalse);
      d = d.stamp(const Duration(seconds: 1))
          .stamp(const Duration(seconds: 2))
          .stamp(const Duration(seconds: 3));
      expect(d.isComplete, isTrue);
    });
  });
}
