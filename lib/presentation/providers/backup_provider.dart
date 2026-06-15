import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../domain/backup/backup_bundle.dart';
import 'artist_favorites_providers.dart';
import 'bookmarks_provider.dart';
import 'equalizer_providers.dart';
import 'hidden_songs_providers.dart';
import 'queue_registry_provider.dart';
import 'settings_providers.dart';
import 'song_ratings_provider.dart';
import 'stats_providers.dart';

/// Builds and applies full-app [BackupBundle]s across every persisted notifier.
class BackupCoordinator {
  BackupCoordinator(this._ref);
  final Ref _ref;

  BackupBundle createBundle() {
    final sections = <String, dynamic>{
      BackupSections.settings:
          _ref.read(settingsProvider.notifier).exportData(),
      BackupSections.ratings:
          _ref.read(songRatingsProvider.notifier).exportData(),
      BackupSections.bookmarks:
          _ref.read(bookmarksProvider.notifier).exportData(),
      BackupSections.favoriteArtists:
          _ref.read(artistFavoritesProvider.notifier).exportData(),
      BackupSections.hiddenSongs:
          _ref.read(hiddenSongsProvider.notifier).exportData(),
      BackupSections.namedQueues:
          _ref.read(queueRegistryProvider.notifier).exportData(),
      BackupSections.playHistory:
          _ref.read(playHistoryProvider.notifier).exportData(),
      BackupSections.customEqPresets:
          _ref.read(customEqPresetsProvider.notifier).exportData(),
    };
    return BackupBundle(
      formatVersion: BackupBundle.currentFormatVersion,
      appVersion: AppInfo.version,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      sections: sections,
    );
  }

  /// Applies every section present in [bundle]; missing sections are left as-is.
  void restore(BackupBundle bundle) {
    final s = bundle.sections;
    if (s.containsKey(BackupSections.settings)) {
      _ref
          .read(settingsProvider.notifier)
          .importData(s[BackupSections.settings]);
    }
    if (s.containsKey(BackupSections.ratings)) {
      _ref
          .read(songRatingsProvider.notifier)
          .importData(s[BackupSections.ratings]);
    }
    if (s.containsKey(BackupSections.bookmarks)) {
      _ref
          .read(bookmarksProvider.notifier)
          .importData(s[BackupSections.bookmarks]);
    }
    if (s.containsKey(BackupSections.favoriteArtists)) {
      _ref
          .read(artistFavoritesProvider.notifier)
          .importData(s[BackupSections.favoriteArtists]);
    }
    if (s.containsKey(BackupSections.hiddenSongs)) {
      _ref
          .read(hiddenSongsProvider.notifier)
          .importData(s[BackupSections.hiddenSongs]);
    }
    if (s.containsKey(BackupSections.namedQueues)) {
      _ref
          .read(queueRegistryProvider.notifier)
          .importData(s[BackupSections.namedQueues]);
    }
    if (s.containsKey(BackupSections.playHistory)) {
      _ref
          .read(playHistoryProvider.notifier)
          .importData(s[BackupSections.playHistory]);
    }
    if (s.containsKey(BackupSections.customEqPresets)) {
      _ref
          .read(customEqPresetsProvider.notifier)
          .importData(s[BackupSections.customEqPresets]);
    }
  }
}

final backupCoordinatorProvider =
    Provider<BackupCoordinator>((ref) => BackupCoordinator(ref));
