import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../albums/album_detail_page.dart';
import '../artists/artist_detail_page.dart';

/// Real-time full-text search across the library. Results are grouped into
/// Artists, Albums, and Songs sections.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  bool _showAllArtists = false;
  bool _showAllAlbums = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(searchQueryProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.lg,
              SpacingTokens.xl,
              SpacingTokens.lg,
              SpacingTokens.md,
            ),
            child: TextField(
              controller: _controller,
              autocorrect: false,
              onChanged: (v) {
                ref.read(searchQueryProvider.notifier).state = v;
                // Reset "show all" state when query changes
                if (_showAllArtists || _showAllAlbums) {
                  setState(() {
                    _showAllArtists = false;
                    _showAllAlbums = false;
                  });
                }
              },
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                hintStyle:
                    AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
                prefixIcon: Icon(Icons.search, color: colors.onSurfaceFaint),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: colors.onSurfaceFaint),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          setState(() {
                            _showAllArtists = false;
                            _showAllAlbums = false;
                          });
                        },
                      ),
                filled: true,
                fillColor: colors.surfaceElevated,
                border: const OutlineInputBorder(
                  borderRadius: RadiusTokens.brSm,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.md,
                  vertical: SpacingTokens.sm,
                ),
              ),
            ),
          ),
          Expanded(child: _buildResults(context, l10n, query)),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AppLocalizations l10n,
    String query,
  ) {
    if (query.trim().isEmpty) {
      return _centered(context, Icons.search, l10n.searchPrompt);
    }

    final q = query.trim();
    final allArtists = ref.watch(artistsProvider).valueOrNull ?? [];
    final allAlbums = ref.watch(albumsProvider).valueOrNull ?? [];
    final songsAsync = ref.watch(searchResultsProvider);

    final matchedArtists = allArtists
        .where((a) => a.name.toLowerCase().contains(q.toLowerCase()))
        .toList();
    final matchedAlbums = allAlbums
        .where((a) =>
            a.name.toLowerCase().contains(q.toLowerCase()) ||
            a.artist.toLowerCase().contains(q.toLowerCase()))
        .toList();

    return songsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) =>
          _centered(context, Icons.error_outline, l10n.errorGeneric),
      data: (songs) {
        final hasArtists = matchedArtists.isNotEmpty;
        final hasAlbums = matchedAlbums.isNotEmpty;
        final hasSongs = songs.isNotEmpty;

        if (!hasArtists && !hasAlbums && !hasSongs) {
          return _centered(
            context,
            Icons.search_off,
            l10n.searchNoResults(query),
          );
        }

        final miniPlayerVisible = ref.watch(hasMediaProvider);
        final bottomPadding =
            playerBarInset(context, miniPlayerVisible: miniPlayerVisible);

        return ListView(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.md,
            0,
            SpacingTokens.md,
            bottomPadding,
          ),
          children: [
            if (hasArtists) ...[
              _SectionHeader(title: l10n.tabArtists),
              ..._buildArtistRows(context, matchedArtists),
            ],
            if (hasAlbums) ...[
              _SectionHeader(title: l10n.tabAlbums),
              ..._buildAlbumRows(context, matchedAlbums),
            ],
            if (hasSongs) ...[
              const _SectionHeader(title: 'Songs'),
              ..._buildSongRows(context, songs),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _buildArtistRows(
      BuildContext context, List<Artist> artists) {
    const maxPreview = 3;
    final showAll = _showAllArtists;
    final displayed =
        showAll ? artists : artists.take(maxPreview).toList();
    final hasMore = artists.length > maxPreview;

    return [
      for (final artist in displayed)
        _ArtistRow(
          artist: artist,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArtistDetailPage(artist: artist),
            ),
          ),
        ),
      if (hasMore && !showAll)
        _SeeAllButton(
          label: 'See all ${artists.length} artists',
          onTap: () => setState(() => _showAllArtists = true),
        ),
    ];
  }

  List<Widget> _buildAlbumRows(
      BuildContext context, List<Album> albums) {
    const maxPreview = 3;
    final showAll = _showAllAlbums;
    final displayed =
        showAll ? albums : albums.take(maxPreview).toList();
    final hasMore = albums.length > maxPreview;

    return [
      for (final album in displayed)
        _AlbumRow(
          album: album,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AlbumDetailPage(album: album),
            ),
          ),
        ),
      if (hasMore && !showAll)
        _SeeAllButton(
          label: 'See all ${albums.length} albums',
          onTap: () => setState(() => _showAllAlbums = true),
        ),
    ];
  }

  List<Widget> _buildSongRows(BuildContext context, List<Song> songs) {
    return [
      for (int i = 0; i < songs.length; i++)
        SongListTile(
          song: songs[i],
          onTap: () => ref
              .read(audioControllerProvider)
              .playQueue(songs, startIndex: i),
          onMore: () => showSongActions(context, songs[i]),
        ),
    ];
  }

  Widget _centered(BuildContext context, IconData icon, String message) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colors.onSurfaceFaint),
          const SizedBox(height: SpacingTokens.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.xs,
        SpacingTokens.lg,
        SpacingTokens.xs,
        SpacingTokens.xs,
      ),
      child: Text(
        title,
        style: AppTextTheme.title.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "See all" button
// ---------------------------------------------------------------------------

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: RadiusTokens.brSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.xs,
          vertical: SpacingTokens.sm,
        ),
        child: Text(
          label,
          style: AppTextTheme.body.copyWith(color: colors.accent),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Artist row
// ---------------------------------------------------------------------------

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.artist, required this.onTap});

  final Artist artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: artist.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: RadiusTokens.brSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.xs,
            vertical: SpacingTokens.sm,
          ),
          child: Row(
            children: [
              AuraArtwork(
                seed: artist.artworkSeed,
                size: 48,
                hasArtwork: artist.hasArtwork,
                artworkId: artist.firstSongId,
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextTheme.title.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${artist.albumCount} ${artist.albumCount == 1 ? 'album' : 'albums'} · '
                      '${artist.songCount} ${artist.songCount == 1 ? 'song' : 'songs'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Album row
// ---------------------------------------------------------------------------

class _AlbumRow extends StatelessWidget {
  const _AlbumRow({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '${album.name}, ${album.artist}',
      child: InkWell(
        onTap: onTap,
        borderRadius: RadiusTokens.brSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.xs,
            vertical: SpacingTokens.sm,
          ),
          child: Row(
            children: [
              AuraArtwork(
                seed: album.artworkSeed,
                size: 48,
                hasArtwork: album.hasArtwork,
                artworkId: int.tryParse(album.id),
                isAlbum: true,
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextTheme.title.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album.year != null
                          ? '${album.artist} · ${album.year}'
                          : album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
