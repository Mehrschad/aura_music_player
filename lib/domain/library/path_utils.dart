/// Pure, platform-agnostic path helpers for the on-device music library.
///
/// Android file paths are POSIX-style (`/storage/emulated/0/Music/…` for
/// internal storage, `/storage/XXXX-XXXX/…` for an SD card), so these operate on
/// `/` separators and never touch `dart:io`, keeping them unit-testable.
abstract final class PathUtils {
  const PathUtils._();

  static const String separator = '/';

  /// The directory containing [path] (no trailing slash). Returns '' for a
  /// bare filename and '/' for a top-level file.
  static String parentDir(String path) {
    final p = _stripTrailing(path);
    final i = p.lastIndexOf(separator);
    if (i < 0) return '';
    if (i == 0) return separator;
    return p.substring(0, i);
  }

  /// The final segment of [path] (file name or folder name).
  static String basename(String path) {
    final p = _stripTrailing(path);
    final i = p.lastIndexOf(separator);
    return i < 0 ? p : p.substring(i + 1);
  }

  /// The lower-cased extension without the dot (e.g. 'flac'), or '' if none.
  static String extension(String path) {
    final name = basename(path);
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// [basename] without its extension.
  static String nameWithoutExtension(String path) {
    final name = basename(path);
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  /// Joins segments with single separators, trimming redundant slashes.
  static String join(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '${_stripTrailing(a)}$separator${_stripLeading(b)}';
  }

  /// Splits [path] into its non-empty segments.
  static List<String> segments(String path) =>
      path.split(separator).where((s) => s.isNotEmpty).toList();

  /// True when [child] is [parent] itself or nested anywhere beneath it.
  /// Segment-aware, so `/a/bc` is NOT considered under `/a/b`.
  static bool isWithin(String child, String parent) {
    final c = _stripTrailing(child);
    final p = _stripTrailing(parent);
    if (p.isEmpty) return true;
    if (c == p) return true;
    return c.startsWith('$p$separator');
  }

  /// A human label for the storage volume a path lives on.
  static String storageLabel(String path) {
    if (path.startsWith('/storage/emulated/0') ||
        path.startsWith('/sdcard') ||
        path.startsWith('/data')) {
      return 'Internal';
    }
    // /storage/XXXX-XXXX/… → removable volume.
    final segs = segments(path);
    if (segs.length >= 2 && segs[0] == 'storage' && segs[1] != 'self') {
      return 'SD card';
    }
    return 'Internal';
  }

  /// Whether [path] sits on removable storage (used to gate SD-card editing).
  static bool isRemovable(String path) => storageLabel(path) == 'SD card';

  static String _stripTrailing(String s) {
    var e = s.length;
    while (e > 1 && s[e - 1] == separator) {
      e--;
    }
    return s.substring(0, e);
  }

  static String _stripLeading(String s) {
    var i = 0;
    while (i < s.length && s[i] == separator) {
      i++;
    }
    return s.substring(i);
  }
}
