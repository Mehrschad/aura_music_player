import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/album.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';

class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({super.key, required this.album});
  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(albumSongsProvider(album.id));
    final miniPlayerVisible = ref.watch(hasMediaProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: colors.background,
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(
                SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.md),
              title: Text(
                album.name,
                style: AppTextTheme.title.copyWith(color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AuraArtwork(
                    seed: album.artworkSeed,
                    size: double.maxFinite,
                    borderRadius: BorderRadius.zero,
                    hasArtwork: album.hasArtwork,
                    artworkId: album.firstSongId,
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

          // Artist + song count + Play button row
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextTheme.body
                              .copyWith(color: colors.onSurfaceMuted),
                        ),
                        Text(
                          l10n.songsCount(album.songCount),
                          style: AppTextTheme.caption
                              .copyWith(color: colors.onSurfaceFaint),
                        ),
                      ],
                    ),
                  ),
                  songsAsync.maybeWhen(
                    data: (songs) => songs.isEmpty
                        ? const SizedBox.shrink()
                        : FilledButton.icon(
                            onPressed: () => ref
                                .read(audioControllerProvider)
                                .playQueue(songs),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.playAll),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // Song list
          songsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('$e',
                    style: AppTextTheme.body
                        .copyWith(color: colors.onSurfaceMuted)),
              ),
            ),
            data: (songs) => SliverPadding(
              padding: EdgeInsets.only(
                bottom:
                    playerBarInset(context, miniPlayerVisible: miniPlayerVisible),
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => SongListTile(
                    song: songs[i],
                    onTap: () => ref
                        .read(audioControllerProvider)
                        .playQueue(songs, startIndex: i),
                    onMore: () => showSongActions(context, songs[i]),
                  ),
                  childCount: songs.length,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
