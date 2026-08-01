import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/song.dart';
import '../../pages/albums/album_detail_page.dart';
import '../../pages/artists/artist_detail_page.dart';
import '../../providers/library_providers.dart';
import '../../providers/media_actions_provider.dart';
import '../../providers/playback_providers.dart';
import '../glass/glass_surface.dart';

// Song actions that are not specific to one screen. They live here (rather than
// on the Now Playing page that first needed them) so every surface showing a
// track — library, search, album, artist, genre, folder, playlist, queue — can
// offer the same complete set from its overflow menu.

/// Resolves the [Album] for [song] and pushes its detail page.
void openAlbumForSong(BuildContext context, WidgetRef ref, Song song) {
  final albums = ref.read(albumsProvider).valueOrNull ?? const <Album>[];
  Album? match;
  for (final a in albums) {
    if (a.id == song.albumId) {
      match = a;
      break;
    }
  }
  if (match == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AlbumDetailPage(album: match!)),
  );
}

/// Resolves the [Artist] for [song] and pushes its detail page.
void openArtistForSong(BuildContext context, WidgetRef ref, Song song) {
  final artists = ref.read(artistsProvider).valueOrNull ?? const <Artist>[];
  Artist? match;
  for (final a in artists) {
    if (a.id == song.artistId || a.name == song.artist) {
      match = a;
      break;
    }
  }
  if (match == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ArtistDetailPage(artist: match!)),
  );
}

/// A read-only metadata sheet for [song].
Future<void> showSongInfo(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SongInfoSheet(song: song),
  );
}

class _SongInfoSheet extends StatelessWidget {
  const _SongInfoSheet({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final rows = <(String, String)>[
      (l10n.tagTitle, song.title),
      (l10n.tagArtist, song.artist),
      (l10n.tagAlbum, song.album),
      if (song.year != null) (l10n.tagYear, '${song.year}'),
      if (song.genre != null && song.genre!.isNotEmpty)
        (l10n.tagGenre, song.genre!),
      (l10n.infoDuration, song.duration.clock),
      if (song.bitrate != null) (l10n.infoBitrate, '${song.bitrate} kbps'),
      (l10n.infoFilePath, song.filePath),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.songInfo,
                  style: AppTextTheme.title.copyWith(color: colors.onSurface)),
              const SizedBox(height: SpacingTokens.md),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(label,
                            style: AppTextTheme.caption
                                .copyWith(color: colors.onSurfaceFaint)),
                      ),
                      Expanded(
                        child: Text(value,
                            style: AppTextTheme.body
                                .copyWith(color: colors.onSurface)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms, then deletes [song] from the device through the OS delete flow.
/// On success the library is rescanned and playback advances past the file.
Future<void> confirmAndDeleteSong(
    BuildContext context, WidgetRef ref, Song song) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colors = ctx.colors;
      return AlertDialog(
        backgroundColor: colors.surface,
        title: Text(l10n.deleteSongTitle,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        content: Text(l10n.deleteSongBody,
            style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;

  HapticFeedback.mediumImpact(); // weighty confirm for a destructive commit
  final deleted = await ref.read(mediaDeleteServiceProvider).deleteSong(song.id);
  if (deleted) {
    // Move off the now-missing file, then rescan the library.
    final controller = ref.read(audioControllerProvider);
    await controller.skipToNext();
    await ref.read(rescanProvider)();
    messenger.showSnackBar(SnackBar(content: Text(l10n.songDeleted)));
  } else {
    messenger.showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
  }
}
