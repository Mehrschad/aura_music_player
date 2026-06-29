import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/genre.dart';
import '../../../domain/models/song.dart';
import '../../providers/cover_palette_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/press_scale.dart';


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

    final palette = ref.watch(coverPaletteProvider((
      seed: genre.artworkSeed,
      hasArtwork: genre.hasArtwork,
      artworkId: genre.firstSongId,
    ))).valueOrNull;
    final accent = palette?.accent ?? SeedPalette.accent(genre.artworkSeed);
    final wash = palette?.wash ?? SeedPalette.wash(genre.artworkSeed);
    final pageBackground =
        Color.alphaBlend(wash.withOpacity(0.18), colors.background);

    final heroHeight = MediaQuery.sizeOf(context).height * 0.40;

    return Scaffold(
      backgroundColor: pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            expandedHeight: heroHeight,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(
                  SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.lg),
              title: Text(
                title,
                style: AppTextTheme.title.copyWith(color: Colors.white),
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
                  // Subtle palette hue wash.
                  DecoratedBox(
                    decoration:
                        BoxDecoration(color: accent.withOpacity(0.10)),
                  ),
                  // Top vignette for legibility.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withOpacity(0.38),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Bottom melt into wash-tinted page background.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.50, 1.0],
                        colors: [
                          Colors.transparent,
                          pageBackground.withOpacity(0.65),
                          pageBackground,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Song count + Play + Shuffle pill buttons.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.xl,
                SpacingTokens.sm,
                SpacingTokens.xl,
                SpacingTokens.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.songsCount(genre.songCount),
                    style: AppTextTheme.caption
                        .copyWith(color: colors.onSurfaceFaint),
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  songsAsync.maybeWhen(
                    data: (songs) => songs.isEmpty
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              Expanded(
                                child: PressScale(
                                  onTap: () =>
                                      _play(ref, songs, shuffle: false),
                                  pressedScale: 0.96,
                                  child: Container(
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: RadiusTokens.brPill,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.play_arrow,
                                            size: 20, color: Colors.white),
                                        const SizedBox(
                                            width: SpacingTokens.sm),
                                        Text(l10n.play,
                                            style: AppTextTheme.action
                                                .copyWith(
                                                    color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.sm),
                              Expanded(
                                child: PressScale(
                                  onTap: () =>
                                      _play(ref, songs, shuffle: true),
                                  pressedScale: 0.96,
                                  child: Container(
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: colors.surfaceElevated,
                                      borderRadius: RadiusTokens.brPill,
                                      border: Border.all(
                                          color: colors.divider),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shuffle,
                                            size: 20,
                                            color: colors.onSurface),
                                        const SizedBox(
                                            width: SpacingTokens.sm),
                                        Text(l10n.shuffle,
                                            style: AppTextTheme.action
                                                .copyWith(
                                                    color:
                                                        colors.onSurface)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
