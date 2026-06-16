import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/genre.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';

/// Detail header height — matches the album/artist detail backdrops.
const double _kExpandedHeight = 240;

class GenreDetailPage extends ConsumerWidget {
  const GenreDetailPage({super.key, required this.genre});
  final Genre genre;

  void _play(WidgetRef ref, List<Song> songs, {required bool shuffle}) {
    if (songs.isEmpty) return;
    final ctrl = ref.read(audioControllerProvider);
    ctrl.setShuffle(shuffle);
    ctrl.playQueue(songs);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(genreSongsProvider(genre.name));
    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final title = genre.isUnknown ? l10n.genreUnknown : genre.name;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: colors.background,
            expandedHeight: _kExpandedHeight,
            pinned: true,
            actions: [
              songsAsync.maybeWhen(
                data: (songs) => songs.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: l10n.shuffleAll,
                        icon: const Icon(Icons.shuffle_rounded,
                            color: Colors.white),
                        onPressed: () => _play(ref, songs, shuffle: true),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(
                  SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.md),
              title: Text(
                title,
                style: AppTextTheme.title.copyWith(color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AuraArtwork(
                    seed: genre.artworkSeed,
                    size: double.maxFinite,
                    borderRadius: BorderRadius.zero,
                    hasArtwork: genre.hasArtwork,
                    artworkId: genre.firstSongId,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Song count + Play-all row.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.xl,
                SpacingTokens.sm,
                SpacingTokens.xl,
                SpacingTokens.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.songsCount(genre.songCount),
                      style: AppTextTheme.caption
                          .copyWith(color: colors.onSurfaceFaint),
                    ),
                  ),
                  songsAsync.maybeWhen(
                    data: (songs) => songs.isEmpty
                        ? const SizedBox.shrink()
                        : FilledButton.icon(
                            onPressed: () =>
                                _play(ref, songs, shuffle: false),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.playAll),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // Song list with quiet loading / on-brand error / empty states.
          songsAsync.when(
            loading: () => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: SizedBox(
                  width: SpacingTokens.xxl,
                  height: SpacingTokens.xxl,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onSurfaceFaint,
                  ),
                ),
              ),
            ),
            error: (_, __) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  l10n.errorGeneric,
                  style:
                      AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
                ),
              ),
            ),
            data: (songs) {
              if (songs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      l10n.libraryEmpty,
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: EdgeInsets.only(
                  bottom: playerBarInset(context,
                      miniPlayerVisible: miniPlayerVisible),
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final song = songs[i];
                      return SongListTile(
                        song: song,
                        onTap: () => ref
                            .read(audioControllerProvider)
                            .playQueue(songs, startIndex: i),
                        onMore: () => showSongActions(context, song),
                      );
                    },
                    childCount: songs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
