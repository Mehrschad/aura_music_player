import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/file_ops_service.dart';

/// The filesystem-operations binding. No-op by default; the device build
/// overrides this with `IoFileOpsService` in `main`.
final fileOpsServiceProvider =
    Provider<FileOpsService>((ref) => const NoopFileOpsService());
