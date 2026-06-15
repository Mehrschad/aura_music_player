import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/genre.dart';
import '../../../domain/models/song.dart';
import '../../providers/async_value_x.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';

class GenreDetailPage extends ConsumerWidget {
  const GenreDetailPage({super.key, required this.genre});
  final Genre genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(genreSongsProvider(genre.name));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(
          genre.isUnknown ? l10n.genreUnknown : genre.name,
          style: AppTextTheme.title.copyWith(color: colors.onSurface),
        ),
        actions: [
          songsAsync.maybeWhen(
            data: (songs) => songs.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.playAll,
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () =>
                        ref.read(audioControllerProvider).playQueue(songs),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: AsyncStateView<List<Song>>(
        value: songsAsync.like,
        isEmpty: (s) => s.isEmpty,
        emptyMessage: l10n.libraryEmpty,
        emptyIcon: Icons.category_outlined,
        onRetry: () => ref.invalidate(songsProvider),
        data: (songs) => ListView.builder(
          padding: EdgeInsets.fromLTRB(
              SpacingTokens.md,
              0,
              SpacingTokens.md,
              playerBarInset(context,
                  miniPlayerVisible: ref.watch(hasMediaProvider))),
          itemCount: songs.length,
          itemBuilder: (_, i) {
            final song = songs[i];
            return SongListTile(
              song: song,
              onTap: () => ref
                  .read(audioControllerProvider)
                  .playQueue(songs, startIndex: i),
              onMore: () => showSongActions(context, song),
            );
          },
        ),
      ),
    );
  }
}
