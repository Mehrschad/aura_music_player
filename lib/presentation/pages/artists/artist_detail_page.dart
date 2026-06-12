import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../providers/artist_bio_providers.dart';
import '../../providers/artist_favorites_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/press_scale.dart';
import '../albums/album_detail_page.dart';

class ArtistDetailPage extends ConsumerWidget {
  const ArtistDetailPage({super.key, required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(artistSongsProvider(artist.id));
    final albumsAsync = ref.watch(artistAlbumsProvider(artist.id));
    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final accent = SeedPalette.accent(artist.artworkSeed);
    final isFav = ref.watch(isArtistFavoriteProvider(artist.id));

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: colors.background,
            expandedHeight: 240,
            pinned: true,
            actions: [
              // Like / favourite this artist.
              IconButton(
                tooltip:
                    isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(artistFavoritesProvider.notifier)
                      .toggle(artist.id);
                },
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? accent : Colors.white,
                ),
              ),
            ],
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
                    child: Text(
                      '${l10n.albumsCount(artist.albumCount)} · ${l10n.songsCount(artist.songCount)}',
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurfaceMuted),
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

          // ── Biography (downloaded from Wikipedia, cached offline) ────────
          SliverToBoxAdapter(child: _ArtistBio(artistName: artist.name)),

          // ── Albums, each its own card in a horizontal rail ──────────────
          albumsAsync.maybeWhen(
            data: (albums) => albums.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverToBoxAdapter(
                    child: _AlbumsRail(albums: albums),
                  ),
            orElse: () =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

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
                bottom: playerBarInset(context,
                    miniPlayerVisible: miniPlayerVisible),
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

/// The artist's Wikipedia summary, shown under the header image. Collapsed to
/// four lines; tapping toggles the full text. Renders nothing while loading
/// or when no biography was found, so the page never jumps around.
class _ArtistBio extends ConsumerStatefulWidget {
  const _ArtistBio({required this.artistName});
  final String artistName;

  @override
  ConsumerState<_ArtistBio> createState() => _ArtistBioState();
}

class _ArtistBioState extends ConsumerState<_ArtistBio> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final bio =
        ref.watch(artistBioProvider(widget.artistName)).valueOrNull;
    if (bio == null || bio.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.xl,
        SpacingTokens.sm,
        SpacingTokens.xl,
        SpacingTokens.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aboutArtist,
            style: AppTextTheme.caption.copyWith(
              color: colors.onSurfaceFaint,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Text(
                bio,
                maxLines: _expanded ? null : 4,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: AppTextTheme.body.copyWith(
                  color: colors.onSurfaceMuted,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal rail of the artist's albums — one tappable card per album.
class _AlbumsRail extends StatelessWidget {
  const _AlbumsRail({required this.albums});
  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.xl,
            SpacingTokens.md,
            SpacingTokens.xl,
            SpacingTokens.sm,
          ),
          child: Text(
            l10n.tabAlbums,
            style: AppTextTheme.caption.copyWith(
              color: colors.onSurfaceFaint,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
            itemCount: albums.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: SpacingTokens.md),
            itemBuilder: (context, i) {
              final album = albums[i];
              return PressScale(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlbumDetailPage(album: album),
                  ),
                ),
                semanticLabel: album.name,
                child: SizedBox(
                  width: 132,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuraArtwork(
                        seed: album.artworkSeed,
                        size: 132,
                        borderRadius: RadiusTokens.brLg,
                        hasArtwork: album.hasArtwork,
                        artworkId: album.firstSongId,
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.body.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        album.year?.toString() ??
                            l10n.songsCount(album.songCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.caption
                            .copyWith(color: colors.onSurfaceMuted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
