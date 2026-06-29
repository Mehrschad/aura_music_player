import 'package:aura_music_player/domain/library/selection_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ordered = ['a', 'b', 'c', 'd', 'e'];

  test('idsInRange returns inclusive forward span', () {
    expect(idsInRange(ordered, 'b', 'd'), {'b', 'c', 'd'});
  });

  test('idsInRange is direction-agnostic', () {
    expect(idsInRange(ordered, 'd', 'b'), {'b', 'c', 'd'});
  });

  test('idsInRange single element when anchor == target', () {
    expect(idsInRange(ordered, 'c', 'c'), {'c'});
  });

  test('idsInRange spans the whole list', () {
    expect(idsInRange(ordered, 'a', 'e'), ordered.toSet());
  });

  test('missing anchor falls back to just the target', () {
    expect(idsInRange(ordered, 'z', 'c'), {'c'});
  });

  test('missing target yields empty', () {
    expect(idsInRange(ordered, 'a', 'z'), isEmpty);
  });
}
