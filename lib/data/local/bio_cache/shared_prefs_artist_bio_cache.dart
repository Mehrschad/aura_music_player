import 'package:shared_preferences/shared_preferences.dart';

/// Persists fetched artist biographies to SharedPreferences so they're
/// available offline. Keyed by the lowercased artist name (stable across
/// library rescans, unlike media-store artist ids).
///
/// Like the lyrics cache, a "miss" marker remembers lookups that found
/// nothing so the background prefetcher doesn't hammer Wikipedia on every
/// launch; misses expire after [missTtl].
class SharedPrefsArtistBioCache {
  static const String _prefix = 'artist_bio_v1_';
  static const String _missPrefix = 'artist_bio_miss_v1_';

  static const Duration missTtl = Duration(days: 30);

  String _key(String artistName) => artistName.trim().toLowerCase();

  Future<String?> read(String artistName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix${_key(artistName)}');
  }

  Future<bool> contains(String artistName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_prefix${_key(artistName)}');
  }

  Future<void> write(String artistName, String bio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${_key(artistName)}', bio);
    await prefs.remove('$_missPrefix${_key(artistName)}');
  }

  Future<void> markMiss(String artistName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_missPrefix${_key(artistName)}',
        DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> hasFreshMiss(String artistName) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('$_missPrefix${_key(artistName)}');
    if (ms == null) return false;
    final age =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    return age < missTtl;
  }
}
