import 'package:aura_music_player/core/utils/seed_color.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accent and wash never exceed 40% saturation', () {
    for (final seed in ['a1', 'album-xyz', 'Northern Glass', '12345', '']) {
      expect(HSVColor.fromColor(SeedPalette.accent(seed)).saturation,
          lessThanOrEqualTo(0.4001));
      expect(HSVColor.fromColor(SeedPalette.wash(seed)).saturation,
          lessThanOrEqualTo(0.4001));
    }
  });

  test('same seed yields a stable hue', () {
    expect(SeedPalette.hueFor('a1'), SeedPalette.hueFor('a1'));
  });
}
