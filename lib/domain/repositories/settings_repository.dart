import '../models/app_settings.dart';

/// Loads and persists [AppSettings].
///
/// [InMemorySettingsRepository] is active (session-scoped). On device, back this
/// with `shared_preferences`: load the JSON map in `load()` and write
/// `settings.toJson()` in `save()` — see the in-memory implementation for the
/// shape.
abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}
