import '../../domain/library/smart_playlist.dart';
import '../../domain/repositories/smart_playlist_repository.dart';

/// Active store, seeded with two example definitions that yield results against
/// the sample library. Swapped for an Isar-backed store on device.
class InMemorySmartPlaylistRepository implements SmartPlaylistRepository {
  final List<SmartPlaylist> _items = [
    const SmartPlaylist(
      id: 'sp_lyrics',
      name: 'With Lyrics',
      rules: [
        SmartRule(
            field: RuleField.hasLyrics, op: RuleOperator.is_, value: 'true'),
      ],
      sortField: RuleField.title,
    ),
    const SmartPlaylist(
      id: 'sp_long',
      name: 'Long Tracks',
      rules: [
        SmartRule(
            field: RuleField.duration,
            op: RuleOperator.greaterThan,
            value: '240'),
      ],
      sortField: RuleField.duration,
      sortDescending: true,
      limit: SmartLimit(kind: SmartLimitKind.songs, value: 10),
    ),
  ];

  var _seq = 0;

  @override
  Future<List<SmartPlaylist>> all() async => List.unmodifiable(_items);

  @override
  Future<SmartPlaylist> save(SmartPlaylist playlist) async {
    if (playlist.id.isEmpty) {
      final created = playlist.copyWith()._withId('sp_user_${_seq++}');
      _items.add(created);
      return created;
    }
    final i = _items.indexWhere((p) => p.id == playlist.id);
    if (i == -1) {
      _items.add(playlist);
    } else {
      _items[i] = playlist;
    }
    return playlist;
  }

  @override
  Future<void> delete(String id) async =>
      _items.removeWhere((p) => p.id == id);
}

extension on SmartPlaylist {
  SmartPlaylist _withId(String id) => SmartPlaylist(
        id: id,
        name: name,
        match: match,
        rules: rules,
        sortField: sortField,
        sortDescending: sortDescending,
        limit: limit,
      );
}
