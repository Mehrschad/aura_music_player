import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/icon_sizes.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/genre.dart';
import '../../../domain/models/playlist.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/recent_searches_provider.dart';
import '../../providers/search_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/top_charts_provider.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/glass/glass_surface.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../albums/album_detail_page.dart';
import '../artists/artist_detail_page.dart';
import '../playlists/playlist_detail_page.dart';

/// Real-time search across the library — songs, artists, albums, playlists and
/// *inside lyrics* — led by a Top Result hero and filtered by scope chips.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String v) {
    ref.read(searchQueryProvider.notifier).state = v;
    // A brand-new query starts from the "All" scope.
    ref.read(searchScopeProvider.notifier).state = SearchScope.all;
  }

  void _applyQuery(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    _setQuery(term);
  }

  void _clear() {
    _controller.clear();
    _setQuery('');
    _focus.requestFocus();
  }

  void _record() {
    final q = ref.read(searchQueryProvider).trim();
    if (q.isNotEmpty) ref.read(recentSearchesProvider.notifier).record(q);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(searchQueryProvider);
    final hasQuery = query.trim().isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title only when idle — typing hands the space to results + Cancel.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: hasQuery
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(SpacingTokens.lg,
                        SpacingTokens.md, SpacingTokens.lg, SpacingTokens.sm),
                    child: Text(
                      l10n.tabSearch,
                      style: AppTextTheme.display.copyWith(
                        color: colors.onSurface,
                        fontSize: 26,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, 0,
                SpacingTokens.lg, SpacingTokens.sm),
            child: Row(
              children: [
                Expanded(
                  child: _SearchField(
                    controller: _controller,
                    focusNode: _focus,
                    showClear: hasQuery,
                    onChanged: _setQuery,
                    onSubmitted: (_) => _record(),
                    onClear: _clear,
                  ),
                ),
                // Cancel dismisses the query and keyboard, back to the browser.
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: hasQuery
                      ? Padding(
                          padding: const EdgeInsets.only(left: SpacingTokens.xs),
                          child: TextButton(
                            onPressed: () {
                              _controller.clear();
                              _setQuery('');
                              _focus.unfocus();
                            },
                            child: Text(
                              l10n.cancel,
                              style: AppTextTheme.body
                                  .copyWith(color: colors.accent),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (hasQuery) const _ScopeChips(),
          Expanded(
            child: hasQuery
                ? _ResultsView(onPlayedResult: _record)
                : _IdleView(onApplyQuery: _applyQuery),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Results (query active)
// ═══════════════════════════════════════════════════════════════════════════

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.onPlayedResult});

  final VoidCallback onPlayedResult;

  static const int _preview = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(searchQueryProvider);
    final scope = ref.watch(searchScopeProvider);
    final bundle = ref.watch(searchBundleProvider);
    final songsAsync = ref.watch(searchResultsProvider);
    final lyricHits = ref.watch(lyricsSearchProvider).valueOrNull ?? const [];

    // The song metadata search is the one async gate; the rest is derived.
    if (songsAsync.isLoading && bundle.isEmpty) {
      return const _ResultsSkeleton();
    }

    final top = scope == SearchScope.all
        ? ref.watch(searchTopResultProvider)
        : null;

    // Lyric hits that aren't already shown as metadata song matches.
    final shownSongIds = {for (final s in bundle.songs) s.id};
    final lyricOnly = [
      for (final s in lyricHits)
        if (!shownSongIds.contains(s.id)) s
    ];

    final showSongs = scope == SearchScope.all || scope == SearchScope.songs;
    final showArtists =
        scope == SearchScope.all || scope == SearchScope.artists;
    final showAlbums = scope == SearchScope.all || scope == SearchScope.albums;
    final showPlaylists =
        scope == SearchScope.all || scope == SearchScope.playlists;
    final showLyrics = showSongs;
    final isAll = scope == SearchScope.all;

    final nothing = bundle.isEmpty && lyricOnly.isEmpty;
    if (nothing && !songsAsync.isLoading) {
      return _Centered(
        icon: Icons.search_off,
        message: l10n.searchNoResults(query),
      );
    }

    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final bottom = playerBarInset(context, miniPlayerVisible: miniPlayerVisible);

    List<Song> songsFor() =>
        isAll ? bundle.songs.take(_preview).toList() : bundle.songs;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (top != null)
          SliverToBoxAdapter(
            child: _TopResultCard(top: top, onPlayed: onPlayedResult),
          ),

        // ── Songs ──────────────────────────────────────────────────────────
        if (showSongs && bundle.songs.isNotEmpty) ...[
          _SliverSectionHeader(
            title: l10n.tabSongs,
            trailing: _PlayAllAction(
              songs: bundle.songs,
              onPlayed: onPlayedResult,
            ),
          ),
          _SliverRows([
            for (final (i, s) in songsFor().indexed)
              _SongResultRow(
                song: s,
                query: query,
                onTap: () {
                  onPlayedResult();
                  ref
                      .read(audioControllerProvider)
                      .playQueue(bundle.songs, startIndex: i);
                },
                onMore: () => showSongActions(context, s),
              ),
          ]),
          if (isAll && bundle.songs.length > _preview)
            _SliverSeeAll(
              label: l10n.searchSeeAllSongs(bundle.songs.length),
              onTap: () => ref.read(searchScopeProvider.notifier).state =
                  SearchScope.songs,
            ),
        ],

        // ── Artists ────────────────────────────────────────────────────────
        if (showArtists && bundle.artists.isNotEmpty) ...[
          _SliverSectionHeader(title: l10n.tabArtists),
          _SliverRows([
            for (final a
                in (isAll ? bundle.artists.take(_preview) : bundle.artists))
              _EntityRow(
                seed: a.artworkSeed,
                artworkId: a.firstSongId,
                hasArtwork: a.hasArtwork,
                circular: true,
                title: a.name,
                subtitle:
                    '${l10n.albumsCount(a.albumCount)} · ${l10n.songsCount(a.songCount)}',
                query: query,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArtistDetailPage(artist: a))),
              ),
          ]),
          if (isAll && bundle.artists.length > _preview)
            _SliverSeeAll(
              label: l10n.searchSeeAllArtists(bundle.artists.length),
              onTap: () => ref.read(searchScopeProvider.notifier).state =
                  SearchScope.artists,
            ),
        ],

        // ── Albums ─────────────────────────────────────────────────────────
        if (showAlbums && bundle.albums.isNotEmpty) ...[
          _SliverSectionHeader(title: l10n.tabAlbums),
          _SliverRows([
            for (final a
                in (isAll ? bundle.albums.take(_preview) : bundle.albums))
              _EntityRow(
                seed: a.artworkSeed,
                artworkId: a.firstSongId,
                hasArtwork: a.hasArtwork,
                title: a.name,
                subtitle: a.year != null ? '${a.artist} · ${a.year}' : a.artist,
                query: query,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AlbumDetailPage(album: a))),
              ),
          ]),
          if (isAll && bundle.albums.length > _preview)
            _SliverSeeAll(
              label: l10n.searchSeeAllAlbums(bundle.albums.length),
              onTap: () => ref.read(searchScopeProvider.notifier).state =
                  SearchScope.albums,
            ),
        ],

        // ── Playlists ──────────────────────────────────────────────────────
        if (showPlaylists && bundle.playlists.isNotEmpty) ...[
          _SliverSectionHeader(title: l10n.tabPlaylists),
          _SliverRows([
            for (final p in (isAll
                ? bundle.playlists.take(_preview)
                : bundle.playlists))
              _PlaylistRow(playlist: p, query: query),
          ]),
        ],

        // ── In lyrics ──────────────────────────────────────────────────────
        if (showLyrics && lyricOnly.isNotEmpty) ...[
          _SliverSectionHeader(title: l10n.searchInLyrics),
          _SliverRows([
            for (final (i, s)
                in (isAll ? lyricOnly.take(3) : lyricOnly).toList().indexed)
              _SongResultRow(
                song: s,
                query: query,
                showLyricGlyph: true,
                onTap: () {
                  onPlayedResult();
                  ref.read(audioControllerProvider).playQueue(
                        isAll ? lyricOnly.take(3).toList() : lyricOnly,
                        startIndex: i,
                      );
                },
                onMore: () => showSongActions(context, s),
              ),
          ]),
        ],

        SliverToBoxAdapter(child: SizedBox(height: bottom + SpacingTokens.lg)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Scope chips
// ═══════════════════════════════════════════════════════════════════════════

class _ScopeChips extends ConsumerWidget {
  const _ScopeChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scope = ref.watch(searchScopeProvider);
    final bundle = ref.watch(searchBundleProvider);
    final lyricHits = ref.watch(lyricsSearchProvider).valueOrNull ?? const [];

    // Only offer a scope chip for a type that actually has matches, so the row
    // never sends the user to an empty filter.
    final items = <(SearchScope, String)>[
      (SearchScope.all, l10n.searchScopeAll),
      if (bundle.songs.isNotEmpty || lyricHits.isNotEmpty)
        (SearchScope.songs, l10n.tabSongs),
      if (bundle.artists.isNotEmpty) (SearchScope.artists, l10n.tabArtists),
      if (bundle.albums.isNotEmpty) (SearchScope.albums, l10n.tabAlbums),
      if (bundle.playlists.isNotEmpty)
        (SearchScope.playlists, l10n.tabPlaylists),
    ];
    if (items.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            SpacingTokens.lg, SpacingTokens.xs, SpacingTokens.lg, SpacingTokens.sm),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.sm),
        itemBuilder: (_, i) {
          final (s, label) = items[i];
          return _ScopeChip(
            label: label,
            selected: s == scope,
            onTap: () => ref.read(searchScopeProvider.notifier).state = s,
          );
        },
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.95,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surfaceElevated,
          borderRadius: RadiusTokens.brPill,
          border: selected ? null : Border.all(color: colors.divider),
        ),
        child: Text(
          label,
          style: AppTextTheme.body.copyWith(
            fontSize: 13,
            color: selected ? colors.onAccent : colors.onSurfaceMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Top result hero
// ═══════════════════════════════════════════════════════════════════════════

class _TopResultCard extends ConsumerWidget {
  const _TopResultCard({required this.top, required this.onPlayed});

  final SearchTop top;
  final VoidCallback onPlayed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    final String kindLabel;
    final String title;
    final String subtitle;
    final String seed;
    final int? artworkId;
    final bool hasArtwork;
    final bool circular;
    VoidCallback onOpen;
    List<Song> Function() playQueueOf;

    switch (top.kind) {
      case SearchKind.song:
        final s = top.value as Song;
        kindLabel = l10n.tabSongs;
        title = s.title;
        subtitle = s.artist;
        seed = s.artworkSeed;
        artworkId = int.tryParse(s.id);
        hasArtwork = s.hasArtwork;
        circular = false;
        onOpen = () {
          onPlayed();
          ref.read(audioControllerProvider).playQueue([s]);
        };
        playQueueOf = () => [s];
      case SearchKind.artist:
        final a = top.value as Artist;
        kindLabel = l10n.tabArtists;
        title = a.name;
        subtitle = '${l10n.songsCount(a.songCount)}';
        seed = a.artworkSeed;
        artworkId = a.firstSongId;
        hasArtwork = a.hasArtwork;
        circular = true;
        onOpen = () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ArtistDetailPage(artist: a)));
        playQueueOf = () =>
            (ref.read(artistSongsProvider(a.id)).valueOrNull ?? const []);
      case SearchKind.album:
        final a = top.value as Album;
        kindLabel = l10n.tabAlbums;
        title = a.name;
        subtitle = a.artist;
        seed = a.artworkSeed;
        artworkId = a.firstSongId;
        hasArtwork = a.hasArtwork;
        circular = false;
        onOpen = () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AlbumDetailPage(album: a)));
        playQueueOf = () =>
            (ref.read(albumSongsProvider(a.id)).valueOrNull ?? const []);
      case SearchKind.playlist:
        final p = top.value as Playlist;
        final byId = {
          for (final s in ref.watch(songsProvider).valueOrNull ?? const <Song>[])
            s.id: s
        };
        final first = p.songIds
            .map((id) => byId[id])
            .firstWhere((s) => s != null, orElse: () => null);
        kindLabel = l10n.tabPlaylists;
        title = p.name;
        subtitle = l10n.songsCount(p.length);
        seed = first?.artworkSeed ?? p.id;
        artworkId = first == null ? null : int.tryParse(first.id);
        hasArtwork = first?.hasArtwork ?? false;
        circular = false;
        onOpen = () => openUserPlaylist(context, p.id);
        playQueueOf = () =>
            [for (final id in p.songIds) if (byId[id] != null) byId[id]!];
    }

    void play() {
      onPlayed();
      final q = playQueueOf();
      if (q.isNotEmpty) ref.read(audioControllerProvider).playQueue(q);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, SpacingTokens.sm),
      child: PressScale(
        onTap: onOpen,
        pressedScale: 0.98,
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.md),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: RadiusTokens.brLg,
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            children: [
              AuraArtwork(
                seed: seed,
                size: 72,
                borderRadius: circular
                    ? BorderRadius.circular(36)
                    : RadiusTokens.brMd,
                hasArtwork: hasArtwork,
                artworkId: artworkId,
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l10n.searchTopResult} · ${kindLabel.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.title.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              _RoundPlay(onTap: play),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundPlay extends StatelessWidget {
  const _RoundPlay({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: AppLocalizations.of(context).play,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
        child: Icon(Icons.play_arrow_rounded, color: colors.onAccent, size: 26),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Rows
// ═══════════════════════════════════════════════════════════════════════════

class _SongResultRow extends StatelessWidget {
  const _SongResultRow({
    required this.song,
    required this.query,
    required this.onTap,
    required this.onMore,
    this.showLyricGlyph = false,
  });

  final Song song;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final bool showLyricGlyph;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: '${song.title}, ${song.artist}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.md, vertical: SpacingTokens.sm),
        child: Row(
          children: [
            AuraArtwork(
              seed: song.artworkSeed,
              size: 48,
              hasArtwork: song.hasArtwork,
              artworkId: int.tryParse(song.id),
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Highlighted(
                    song.title,
                    query,
                    style: AppTextTheme.title.copyWith(color: colors.onSurface),
                    highlight: colors.accent,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (showLyricGlyph) ...[
                        Icon(Icons.lyrics_outlined,
                            size: 13, color: colors.accent),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: _Highlighted(
                          song.artist,
                          query,
                          style: AppTextTheme.body
                              .copyWith(color: colors.onSurfaceMuted),
                          highlight: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _MoreButton(onTap: onMore),
          ],
        ),
      ),
    );
  }
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({
    required this.seed,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.onTap,
    this.artworkId,
    this.hasArtwork = false,
    this.circular = false,
    this.glyph,
  });

  final String seed;
  final String title;
  final String subtitle;
  final String query;
  final VoidCallback onTap;
  final int? artworkId;
  final bool hasArtwork;
  final bool circular;
  final IconData? glyph;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.md, vertical: SpacingTokens.sm),
        child: Row(
          children: [
            if (glyph != null)
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: RadiusTokens.brMd,
                ),
                child: Icon(glyph, color: colors.accent, size: 22),
              )
            else
              AuraArtwork(
                seed: seed,
                size: 48,
                borderRadius:
                    circular ? BorderRadius.circular(24) : RadiusTokens.brMd,
                hasArtwork: hasArtwork,
                artworkId: artworkId,
              ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Highlighted(
                    title,
                    query,
                    style: AppTextTheme.title.copyWith(color: colors.onSurface),
                    highlight: colors.accent,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.body
                        .copyWith(color: colors.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceFaint, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PlaylistRow extends ConsumerWidget {
  const _PlaylistRow({required this.playlist, required this.query});

  final Playlist playlist;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final byId = {
      for (final s in ref.watch(songsProvider).valueOrNull ?? const <Song>[])
        s.id: s
    };
    final first = playlist.songIds
        .map((id) => byId[id])
        .firstWhere((s) => s != null, orElse: () => null);
    return _EntityRow(
      seed: first?.artworkSeed ?? playlist.id,
      artworkId: first == null ? null : int.tryParse(first.id),
      hasArtwork: first?.hasArtwork ?? false,
      glyph: first == null ? Icons.queue_music_rounded : null,
      title: playlist.name,
      subtitle: l10n.songsCount(playlist.length),
      query: query,
      onTap: () => openUserPlaylist(context, playlist.id),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: SpacingTokens.xs),
        child: Icon(Icons.more_vert, color: colors.onSurfaceFaint, size: 20),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Highlighted text — matched substring painted in the accent.
// ═══════════════════════════════════════════════════════════════════════════

class _Highlighted extends StatelessWidget {
  const _Highlighted(
    this.text,
    this.query, {
    required this.style,
    required this.highlight,
  });

  final String text;
  final String query;
  final TextStyle style;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final idx = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
    if (idx < 0) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    final hlStyle =
        style.copyWith(color: highlight, fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(text: text.substring(idx, idx + q.length), style: hlStyle),
          if (idx + q.length < text.length)
            TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section header + see-all + play-all (slivers)
// ═══════════════════════════════════════════════════════════════════════════

class _SliverSectionHeader extends StatelessWidget {
  const _SliverSectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(SpacingTokens.md, SpacingTokens.lg,
            SpacingTokens.md, SpacingTokens.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: colors.onSurfaceFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _PlayAllAction extends ConsumerWidget {
  const _PlayAllAction({required this.songs, required this.onPlayed});

  final List<Song> songs;
  final VoidCallback onPlayed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return PressScale(
      onTap: () {
        onPlayed();
        ref.read(audioControllerProvider).playQueue(songs);
      },
      pressedScale: 0.94,
      semanticLabel: l10n.playAll,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, color: colors.accent, size: 18),
          const SizedBox(width: 2),
          Text(
            l10n.playAll,
            style: AppTextTheme.body.copyWith(
              color: colors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverSeeAll extends StatelessWidget {
  const _SliverSeeAll({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SliverToBoxAdapter(
      child: PressScale(
        onTap: onTap,
        pressedScale: 0.97,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md, vertical: SpacingTokens.sm),
          child: Row(
            children: [
              Text(
                label,
                style: AppTextTheme.body.copyWith(
                    color: colors.accent, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, color: colors.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a list of row widgets in a [SliverList].
class _SliverRows extends StatelessWidget {
  const _SliverRows(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverList(delegate: SliverChildListDelegate(children));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Loading skeleton
// ═══════════════════════════════════════════════════════════════════════════

class _ResultsSkeleton extends StatefulWidget {
  const _ResultsSkeleton();

  @override
  State<_ResultsSkeleton> createState() => _ResultsSkeletonState();
}

class _ResultsSkeletonState extends State<_ResultsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final o = reduce ? 0.08 : (0.05 + 0.06 * _ctrl.value);
        final bar = colors.onSurface.withOpacity(o);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md, vertical: SpacingTokens.md),
          itemCount: 8,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: bar, borderRadius: RadiusTokens.brMd),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 13, width: 180, color: bar),
                      const SizedBox(height: 8),
                      Container(height: 11, width: 110, color: bar),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Idle view (empty query): recent searches · recently played · browse genres
// ═══════════════════════════════════════════════════════════════════════════

class _IdleView extends ConsumerWidget {
  const _IdleView({required this.onApplyQuery});

  final ValueChanged<String> onApplyQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recents = ref.watch(recentSearchesProvider);
    final recentlyPlayed = ref.watch(jumpBackInProvider);
    final genres = ref.watch(genresProvider).valueOrNull ?? const <Genre>[];

    if (recents.isEmpty && recentlyPlayed.isEmpty && genres.isEmpty) {
      return _Centered(icon: Icons.search, message: l10n.searchPrompt);
    }

    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final bottom = playerBarInset(context, miniPlayerVisible: miniPlayerVisible);

    return ListView(
      padding: EdgeInsets.only(bottom: bottom, top: SpacingTokens.xs),
      children: [
        if (recents.isNotEmpty)
          _RecentSearches(
            terms: recents,
            onTap: onApplyQuery,
            onRemove: (t) => ref.read(recentSearchesProvider.notifier).remove(t),
            onClear: () => ref.read(recentSearchesProvider.notifier).clear(),
          ),
        if (recentlyPlayed.isNotEmpty)
          _RecentlyPlayedRail(songs: recentlyPlayed),
        if (genres.isNotEmpty)
          _BrowseGenres(genres: genres, onTap: (g) => onApplyQuery(g.name)),
      ],
    );
  }
}

class _RecentlyPlayedRail extends ConsumerWidget {
  const _RecentlyPlayedRail({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SpacingTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, 0, SpacingTokens.lg, SpacingTokens.sm),
            child: _SubHead(l10n.searchRecentlyPlayed),
          ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
              itemCount: songs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: SpacingTokens.md),
              itemBuilder: (_, i) => _RecentCard(
                song: songs[i],
                onTap: () => ref
                    .read(audioControllerProvider)
                    .playQueue(songs, startIndex: i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.96,
      semanticLabel: '${song.title}, ${song.artist}',
      child: SizedBox(
        width: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuraArtwork(
              seed: song.artworkSeed,
              size: 116,
              borderRadius: RadiusTokens.brMd,
              hasArtwork: song.hasArtwork,
              artworkId: int.tryParse(song.id),
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextTheme.body.copyWith(
                  color: colors.onSurface, fontWeight: FontWeight.w500),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Search field
// ═══════════════════════════════════════════════════════════════════════════

class _SearchField extends ConsumerWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.showClear,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final intensity =
        ref.watch(settingsProvider.select((s) => s.glassIntensity));
    return GlassSurface(
      borderRadius: RadiusTokens.brPill,
      intensity: intensity,
      level: GlassLevel.thin,
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            Icon(Icons.search, size: IconSizes.md, color: colors.onSurfaceFaint),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autocorrect: false,
                textInputAction: TextInputAction.search,
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Browse genres
// ═══════════════════════════════════════════════════════════════════════════

class _BrowseGenres extends StatelessWidget {
  const _BrowseGenres({required this.genres, required this.onTap});

  final List<Genre> genres;
  final ValueChanged<Genre> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth -
                SpacingTokens.lg * 2 -
                SpacingTokens.sm) /
            2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, SpacingTokens.lg,
              SpacingTokens.lg, SpacingTokens.md),
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
                        label:
                            genre.isUnknown ? l10n.genreUnknown : genre.name,
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
    final colors = context.colors;
    final seed = genre.artworkSeed;
    final accent = SeedPalette.accent(seed);
    // On-brand editorial tile: dark elevated surface, a seed-tinted glyph and
    // a hairline accent edge — quieter and more consistent than the old
    // full-bleed gradient card.
    return PressScale(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: label,
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withOpacity(0.12), colors.surfaceElevated),
          borderRadius: RadiusTokens.brMd,
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.equalizer_rounded, color: accent, size: 22),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.title.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Recent searches
// ═══════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, SpacingTokens.xs,
          SpacingTokens.lg, SpacingTokens.sm),
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
    return PressScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.md, vertical: SpacingTokens.xs),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brPill,
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: IconSizes.xs, color: colors.onSurfaceFaint),
            const SizedBox(width: SpacingTokens.xs),
            Text(label,
                style: AppTextTheme.body.copyWith(color: colors.onSurface)),
            const SizedBox(width: SpacingTokens.xs),
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

// ═══════════════════════════════════════════════════════════════════════════
// Shared bits
// ═══════════════════════════════════════════════════════════════════════════

/// The shared DS "SubHead" label used for browse/section headers.
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

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
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
