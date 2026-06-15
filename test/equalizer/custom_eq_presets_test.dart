import 'package:aura_music_player/domain/models/named_eq_preset.dart';
import 'package:aura_music_player/presentation/providers/equalizer_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NamedEqPreset _preset(String id) => NamedEqPreset(
      id: id,
      name: 'Preset $id',
      gains: const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  late ProviderContainer container;
  CustomEqPresetsNotifier notifier() =>
      container.read(customEqPresetsProvider.notifier);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('add increments the list', () {
    expect(notifier().add(_preset('1')), isTrue);
    expect(notifier().add(_preset('2')), isTrue);
    expect(container.read(customEqPresetsProvider).length, 2);
  });

  test('add respects the maxPresets cap', () {
    for (var i = 0; i < CustomEqPresetsNotifier.maxPresets; i++) {
      expect(notifier().add(_preset('$i')), isTrue);
    }
    expect(notifier().add(_preset('overflow')), isFalse);
    expect(container.read(customEqPresetsProvider).length,
        CustomEqPresetsNotifier.maxPresets);
  });

  test('rename changes the name', () {
    notifier().add(_preset('1'));
    notifier().rename('1', 'Renamed');
    expect(container.read(customEqPresetsProvider).single.name, 'Renamed');
  });

  test('remove drops the preset', () {
    notifier()
      ..add(_preset('1'))
      ..add(_preset('2'))
      ..remove('1');
    final state = container.read(customEqPresetsProvider);
    expect(state.length, 1);
    expect(state.single.id, '2');
  });

  test('exportData/importData round-trips the list', () {
    notifier()
      ..add(_preset('1'))
      ..add(_preset('2'));
    final exported = notifier().exportData();

    final other = ProviderContainer();
    addTearDown(other.dispose);
    final otherNotifier = other.read(customEqPresetsProvider.notifier);
    otherNotifier.importData(exported);
    expect(other.read(customEqPresetsProvider).map((p) => p.id).toList(),
        ['1', '2']);
  });
}
