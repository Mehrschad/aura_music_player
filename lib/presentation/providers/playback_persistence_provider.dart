import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/platform/playback_persistence.dart';

/// The service that remembers the last playback session across cold starts.
///
/// Null by default; [main] overrides it with a `SharedPreferences`-backed
/// instance on device. Tests leave it null, so the [PlaybackPersistor] becomes
/// an inert no-op and never touches disk.
final playbackPersistenceProvider =
    Provider<PlaybackPersistence?>((ref) => null);
