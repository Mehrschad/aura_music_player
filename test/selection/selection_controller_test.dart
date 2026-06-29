import 'package:aura_music_player/presentation/providers/selection_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SelectionController c;
  setUp(() => c = SelectionController());

  test('starts inactive and empty', () {
    expect(c.state.active, isFalse);
    expect(c.state.isEmpty, isTrue);
  });

  test('enter activates with one id as anchor', () {
    c.enter('b');
    expect(c.state.active, isTrue);
    expect(c.state.ids, {'b'});
    expect(c.state.anchor, 'b');
  });

  test('toggle adds and removes; emptying exits selection mode', () {
    c.enter('a');
    c.toggle('b');
    expect(c.state.ids, {'a', 'b'});
    c.toggle('a');
    expect(c.state.ids, {'b'});
    c.toggle('b');
    expect(c.state.active, isFalse);
    expect(c.state.isEmpty, isTrue);
  });

  test('toggle outside selection mode enters it', () {
    c.toggle('x');
    expect(c.state.active, isTrue);
    expect(c.state.ids, {'x'});
  });

  test('selectRange spans from anchor to target inclusively', () {
    const ordered = ['a', 'b', 'c', 'd', 'e'];
    c.enter('b'); // anchor = b
    c.selectRange(ordered, 'd');
    expect(c.state.ids, {'b', 'c', 'd'});
    expect(c.state.anchor, 'd');
  });

  test('selectAll picks everything', () {
    c.selectAll(['a', 'b', 'c']);
    expect(c.state.active, isTrue);
    expect(c.state.ids, {'a', 'b', 'c'});
  });

  test('invert flips against the universe and can exit when emptied', () {
    c.selectAll(['a', 'b', 'c']);
    c.invert(['a', 'b', 'c']);
    expect(c.state.active, isFalse);
    expect(c.state.isEmpty, isTrue);

    c.enter('a');
    c.invert(['a', 'b', 'c']);
    expect(c.state.ids, {'b', 'c'});
  });

  test('clear leaves selection mode', () {
    c.selectAll(['a', 'b']);
    c.clear();
    expect(c.state.active, isFalse);
    expect(c.state.isEmpty, isTrue);
  });
}
