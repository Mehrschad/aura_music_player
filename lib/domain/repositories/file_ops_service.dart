/// Filesystem operations on music files. The default binding is a no-op so the
/// app (and tests) run anywhere; the device build overrides it with an
/// implementation backed by `dart:io` (see `IoFileOpsService`).
abstract interface class FileOpsService {
  /// Renames the file at [fromPath] to [newName] (name only, same directory).
  /// Returns the new absolute path, or null on failure / name collision.
  Future<String?> rename(String fromPath, String newName);

  /// Moves [fromPath] into [destDir], keeping its filename. Returns the new
  /// path or null.
  Future<String?> move(String fromPath, String destDir);

  /// Copies [fromPath] into [destDir]. Returns the new path or null.
  Future<String?> copy(String fromPath, String destDir);

  /// Deletes [path]. Returns true on success.
  Future<bool> delete(String path);

  /// Whether [path] already exists (collision checks before rename/move).
  Future<bool> exists(String path);
}

/// Default binding: every operation is a no-op. Keeps the app runnable on
/// platforms without file access and keeps tests off the real filesystem.
class NoopFileOpsService implements FileOpsService {
  const NoopFileOpsService();

  @override
  Future<String?> rename(String fromPath, String newName) async => null;

  @override
  Future<String?> move(String fromPath, String destDir) async => null;

  @override
  Future<String?> copy(String fromPath, String destDir) async => null;

  @override
  Future<bool> delete(String path) async => false;

  @override
  Future<bool> exists(String path) async => false;
}
