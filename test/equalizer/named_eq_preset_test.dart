import 'package:aura_music_player/domain/models/named_eq_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const preset = NamedEqPreset(
    id: 'p1',
    name: 'My curve',
    gains: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    bassBoost: 300,
    stereoWidth: 0.5,
  );

  group('NamedEqPreset', () {
    test('JSON round-trip preserves every field', () {
      final restored = NamedEqPreset.fromJson(preset.toJson());
      expect(restored, preset);
      expect(restored.id, 'p1');
      expect(restored.name, 'My curve');
      expect(restored.gains, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(restored.bassBoost, 300);
      expect(restored.stereoWidth, 0.5);
    });

    test('fromJson tolerates missing bassBoost/stereoWidth (defaults 0)', () {
      final p = NamedEqPreset.fromJson({
        'id': 'x',
        'name': 'n',
        'gains': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      });
      expect(p.bassBoost, 0);
      expect(p.stereoWidth, 0);
    });

    test('equality compares all fields including gains', () {
      expect(preset == preset.copyWith(), isTrue);
      final diffGains = NamedEqPreset(
        id: preset.id,
        name: preset.name,
        gains: const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        bassBoost: preset.bassBoost,
        stereoWidth: preset.stereoWidth,
      );
      expect(preset == diffGains, isFalse);
    });

    test('copyWith(name) changes only the name', () {
      final renamed = preset.copyWith(name: 'Other');
      expect(renamed.name, 'Other');
      expect(renamed.id, preset.id);
      expect(renamed.gains, preset.gains);
      expect(renamed.bassBoost, preset.bassBoost);
      expect(renamed.stereoWidth, preset.stereoWidth);
    });
  });
}
