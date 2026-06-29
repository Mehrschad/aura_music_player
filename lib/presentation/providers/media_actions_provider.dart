import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/platform/media_delete_service.dart';

/// The platform service that deletes audio files through the OS delete flow.
final mediaDeleteServiceProvider = Provider<MediaDeleteService>(
  (ref) => const MediaDeleteService(),
);
