import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/artist.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';

class ArtistDetailPage extends ConsumerWidget {
  const ArtistDetailPage({super.key, required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(artistSongsProvider(artist.id));
    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final accent = SeedPalette.accent(artist.artworkSeed);

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: colors.background,
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(
                SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.md),
              title: Text(
                artist.name,
                style: AppTextTheme.title.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: AuraArtwork(
                      seed: artist.artworkSeed,
                      size: double.maxFinite,
                      borderRadius: BorderRadius.zero,
                      hasArtwork: artist.hasArtwork,
                      artworkId: artist.firstSongId,
                    ),
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
                          '${l10n.albumsCount(artist.albumCount)} · ${l10n.songsCount(artist.songCount)}',
                          style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
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

          songsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('$e',
                    style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
              ),
            ),
            data: (songs) => SliverPadding(
              padding: EdgeInsets.only(
                bottom: playerBarInset(context, miniPlayerVisible: miniPlayerVisible),
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
