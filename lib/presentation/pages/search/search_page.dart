import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/icon_sizes.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/genre.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/recent_searches_provider.dart';
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
              SpacingTokens.md,
              SpacingTokens.lg,
              SpacingTokens.sm,
            ),
            // Large screen title (24 / 600 / -0.5), per the DS Search header.
            child: Text(
              l10n.tabSearch,
              style: AppTextTheme.display.copyWith(
                color: colors.onSurface,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.lg,
              0,
              SpacingTokens.lg,
              SpacingTokens.md,
            ),
            child: _SearchField(
              controller: _controller,
              showClear: query.isNotEmpty,
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
              onSubmitted: (v) {
                final t = v.trim();
                if (t.isNotEmpty) {
                  ref.read(recentSearchesProvider.notifier).record(t);
                }
              },
              onClear: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).state = '';
                setState(() {
                  _showAllArtists = false;
                  _showAllAlbums = false;
                });
              },
            ),
          ),
          Expanded(child: _buildResults(context, l10n, query)),
        ],
      ),
    );
  }

  /// Fills the search field with [term] and runs the query (genre tap, recent).
  void _applyQuery(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    ref.read(searchQueryProvider.notifier).state = term;
    setState(() {
      _showAllArtists = false;
      _showAllAlbums = false;
    });
  }

  Widget _buildResults(
    BuildContext context,
    AppLocalizations l10n,
    String query,
  ) {
    if (query.trim().isEmpty) {
      final recents = ref.watch(recentSearchesProvider);
      final genres = ref.watch(genresProvider).valueOrNull ?? const [];
      if (recents.isEmpty && genres.isEmpty) {
        return _centered(context, Icons.search, l10n.searchPrompt);
      }
      final miniPlayerVisible = ref.watch(hasMediaProvider);
      final bottomPadding =
          playerBarInset(context, miniPlayerVisible: miniPlayerVisible);
      // Empty query: recent searches (if any) above the genre browser.
      return ListView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          if (recents.isNotEmpty)
            _RecentSearches(
              terms: recents,
              onTap: _applyQuery,
              onRemove: (t) =>
                  ref.read(recentSearchesProvider.notifier).remove(t),
              onClear: () => ref.read(recentSearchesProvider.notifier).clear(),
            ),
          if (genres.isNotEmpty)
            _BrowseGenres(
              genres: genres,
              onTap: (g) => _applyQuery(g.name),
            ),
        ],
      );
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
              _SectionHeader(title: l10n.tabSongs),
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
          label: AppLocalizations.of(context).searchSeeAllArtists(artists.length),
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
          label: AppLocalizations.of(context).searchSeeAllAlbums(albums.length),
          onTap: () => setState(() => _showAllAlbums = true),
        ),
    ];
  }

  List<Widget> _buildSongRows(BuildContext context, List<Song> songs) {
    return [
      for (int i = 0; i < songs.length; i++)
        SongListTile(
          song: songs[i],
          onTap: () {
            // A played result is the strongest signal the search mattered.
            final q = ref.read(searchQueryProvider).trim();
            if (q.isNotEmpty) {
              ref.read(recentSearchesProvider.notifier).record(q);
            }
            ref
                .read(audioControllerProvider)
                .playQueue(songs, startIndex: i);
          },
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
// Section header — DS SubHead: uppercase, faint, weight 600, ls 0.3.
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.xs,
        SpacingTokens.lg,
        SpacingTokens.xs,
        SpacingTokens.xs,
      ),
      child: _SubHead(title),
    );
  }
}

/// The shared DS "SubHead" label used for grouped-section and browse headers.
class _SubHead extends StatelessWidget {
  const _SubHead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text.toUpperCase(),
      style: AppTextTheme.body.copyWith(
        color: colors.onSurfaceFaint,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pill search field
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.showClear,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: RadiusTokens.brPill,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: IconSizes.md, color: colors.onSurfaceFaint),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autocorrect: false,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: l10n.searchHint,
                hintStyle:
                    AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
              ),
            ),
          ),
          if (showClear)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Semantics(
                button: true,
                label: l10n.searchClear,
                child: Padding(
                  padding: const EdgeInsets.only(left: SpacingTokens.sm),
                  child: Icon(Icons.close,
                      size: IconSizes.sm, color: colors.onSurfaceFaint),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Browse genres — a wrap of seed-gradient cards (shown on the empty query).
// ---------------------------------------------------------------------------

class _BrowseGenres extends StatelessWidget {
  const _BrowseGenres({required this.genres, required this.onTap});

  final List<Genre> genres;
  final ValueChanged<Genre> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns: each tile spans ~half the row minus the inter-tile gap.
        final tileWidth =
            (constraints.maxWidth - SpacingTokens.sm) / 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.lg,
            SpacingTokens.xs,
            SpacingTokens.lg,
            SpacingTokens.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SubHead(l10n.browseGenres),
              const SizedBox(height: SpacingTokens.md),
              Wrap(
                spacing: SpacingTokens.sm,
                runSpacing: SpacingTokens.sm,
                children: [
                  for (final genre in genres)
                    SizedBox(
                      width: tileWidth,
                      child: _GenreCard(
                        genre: genre,
                        label: genre.isUnknown ? l10n.genreUnknown : genre.name,
                        onTap: () => onTap(genre),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GenreCard extends StatelessWidget {
  const _GenreCard({
    required this.genre,
    required this.label,
    required this.onTap,
  });

  final Genre genre;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Per-genre calm gradient from the clamped seed palette.
    final seed = genre.artworkSeed;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [SeedPalette.accent(seed), SeedPalette.wash(seed)],
    );
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 76,
          padding: const EdgeInsets.all(SpacingTokens.md),
          alignment: Alignment.bottomLeft,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: RadiusTokens.brMd,
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextTheme.title.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
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
                artworkId: album.firstSongId,
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

// ---------------------------------------------------------------------------
// Recent searches (empty-state view)
// ---------------------------------------------------------------------------

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.terms,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> terms;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.lg,
        SpacingTokens.xs,
        SpacingTokens.lg,
        SpacingTokens.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _SubHead(l10n.recentSearches)),
              TextButton(
                onPressed: onClear,
                child: Text(
                  l10n.clearRecentSearches,
                  style: AppTextTheme.body.copyWith(color: colors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.xs),
          Wrap(
            spacing: SpacingTokens.sm,
            runSpacing: SpacingTokens.sm,
            children: [
              for (final term in terms)
                _RecentChip(
                  label: term,
                  onTap: () => onTap(term),
                  onRemove: () => onRemove(term),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: RadiusTokens.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.xs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: IconSizes.xs, color: colors.onSurfaceFaint),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              label,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
            ),
            const SizedBox(width: SpacingTokens.xs),
            // Tappable X removes just this term.
            Semantics(
              button: true,
              label: l10n.delete,
              child: GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close,
                    size: IconSizes.xs, color: colors.onSurfaceFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
