import '../../domain/models/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Session-scoped settings store. On device, swap for a `shared_preferences`
/// implementation that reads/writes the same `toJson()` map under a single key.
class InMemorySettingsRepository implements SettingsRepository {
  AppSettings _settings = AppSettings.defaults;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}
