import 'dart:io';

import '../../../domain/library/path_utils.dart';
import '../../../domain/repositories/file_ops_service.dart';

/// `dart:io`-backed [FileOpsService] for the device build. Wired in `main` by
/// overriding `fileOpsServiceProvider`. Every operation fails soft (returns
/// null/false) rather than throwing, so the UI can show a single error path.
class IoFileOpsService implements FileOpsService {
  const IoFileOpsService();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<String?> rename(String fromPath, String newName) async {
    final dir = PathUtils.parentDir(fromPath);
    final target = PathUtils.join(dir, newName);
    return _guard(() async {
      if (await File(target).exists()) return null;
      final moved = await File(fromPath).rename(target);
      return moved.path;
    });
  }

  @override
  Future<String?> move(String fromPath, String destDir) async {
    final target = PathUtils.join(destDir, PathUtils.basename(fromPath));
    return _guard(() async {
      if (await File(target).exists()) return null;
      await Directory(destDir).create(recursive: true);
      try {
        final moved = await File(fromPath).rename(target);
        return moved.path;
      } on FileSystemException {
        // Cross-volume rename fails (e.g. internal → SD): copy then delete.
        final copied = await File(fromPath).copy(target);
        await File(fromPath).delete();
        return copied.path;
      }
    });
  }

  @override
  Future<String?> copy(String fromPath, String destDir) async {
    final target = PathUtils.join(destDir, PathUtils.basename(fromPath));
    return _guard(() async {
      if (await File(target).exists()) return null;
      await Directory(destDir).create(recursive: true);
      final copied = await File(fromPath).copy(target);
      return copied.path;
    });
  }

  @override
  Future<bool> delete(String path) async {
    return await _guard(() async {
          await File(path).delete();
          return 'ok';
        }) !=
        null;
  }

  Future<T?> _guard<T>(Future<T?> Function() op) async {
    try {
      return await op();
    } on FileSystemException {
      return null;
    }
  }
}
