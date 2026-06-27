import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/genre.dart';
import '../../../domain/models/library_sort.dart';
import '../../../domain/models/song.dart';
import '../../providers/async_value_x.dart';
import '../../../domain/taste/smart_collection.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../../providers/selection_providers.dart';
import '../../providers/smart_collections_provider.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/library/album_grid_tile.dart';
import '../../widgets/library/artist_list_tile.dart';
import '../../widgets/library/genre_list_tile.dart';
import '../../widgets/library/library_controls.dart';
import '../../widgets/library/selection_bar.dart';
import '../../widgets/library/song_compact_tile.dart';
import '../../widgets/library/song_grid_tile.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/press_scale.dart';
import '../albums/album_detail_page.dart';
import '../artists/artist_detail_page.dart';
import '../folders/folder_browser_page.dart';
import '../genres/genre_detail_page.dart';
import '../settings/settings_page.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  static const String _listId = SelectionScopes.library;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  // True once any descendant scroll view has scrolled > 20 logical pixels.
  // Drives the largeTitle → headline morph per iOS 26 spec §10.
  bool _scrolled = false;

  void _play(List<Song> queue, int index) {
    ref.read(audioControllerProvider).playQueue(queue, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final segment = ref.watch(librarySegmentProvider);
    final songsAsync = ref.watch(sortedSongsProvider);
    final sort = ref.watch(librarySortProvider);
    final mode = ref.watch(libraryDisplayModeProvider);
    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final selecting = ref.watch(
        selectionProvider(LibraryPage._listId).select((s) => s.active));
    final allSongs = songsAsync.valueOrNull ?? const <Song>[];

    // Collapsed = title at headline; expanded = big editorial display title.
    final collapsed = _scrolled && !selecting;

    // Album count for the editorial header's eyebrow stat line.
    final albumCount = allSongs.map((s) => s.albumId).toSet().length;

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        final scrolled = n.metrics.pixels > 20;
        if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
        return false; // don't absorb — let the scroll view handle it too
      },
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selecting)
              SelectionBar(listId: LibraryPage._listId, allSongs: allSongs)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.sm, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big wordmark + trailing actions. The title morphs down to
                    // a compact headline as the page scrolls (iOS large-title).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                            style: collapsed
                                ? AppTextTheme.headline
                                    .copyWith(color: colors.onSurface)
                                : AppTextTheme.display.copyWith(
                                    color: colors.onSurface,
                                    fontSize: 34,
                                    height: 1.0,
                                    letterSpacing: -1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                            child: const Text('Aura'),
                          ),
                        ),
                        DisplayModeButton(
                          mode: mode,
                          onChanged: (m) => ref
                              .read(libraryDisplayModeProvider.notifier)
                              .state = m,
                        ),
                        IconButton(
                          tooltip: l10n.folders,
                          onPressed: () => openFolderBrowser(context),
                          icon: const Icon(Icons.folder_outlined),
                        ),
                        IconButton(
                          tooltip: l10n.sortLabel,
                          onPressed: () => showSortSheet(
                            context,
                            current: sort,
                            onChanged: (s) => ref
                                .read(librarySortProvider.notifier)
                                .state = s,
                          ),
                          icon: const Icon(Icons.sort),
                        ),
                        IconButton(
                          tooltip: l10n.settings,
                          onPressed: () => openSettings(context),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                    // Eyebrow stat line — collapses away as the page scrolls.
                    ClipRect(
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        alignment: Alignment.topLeft,
                        heightFactor: collapsed ? 0.0 : 1.0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: collapsed ? 0.0 : 1.0,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1, bottom: 6),
                            child: Text(
                              '${l10n.songsCount(allSongs.length)} · '
                                      '${l10n.albumsCount(albumCount)}'
                                  .toUpperCase(),
                              style: AppTextTheme.caption.copyWith(
                                color: colors.onSurfaceFaint,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // "For You" — intelligent, ephemeral collections from the taste
            // engine (Your Mix, Heavy Rotation, Hidden Gems, Rediscover…). Tucks
            // away on scroll. Nothing here is saved unless the user explicitly
            // adds a card to their playlists.
            if (!selecting)
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: collapsed
                    ? const SizedBox(width: double.infinity)
                    : const _ForYouSection(),
              ),
            if (!selecting) _SegmentRow(selected: segment),
            Expanded(
              child: switch (segment) {
                LibrarySegment.songs => AsyncStateView<List<Song>>(
                    value: songsAsync.like,
                    isEmpty: (s) => s.isEmpty,
                    emptyMessage: l10n.libraryEmpty,
                    onRetry: () => ref.invalidate(songsProvider),
                    data: (songs) => _SongsBody(
                      songs: songs,
                      mode: mode,
                      miniPlayerVisible: miniPlayerVisible,
                      onPlayAt: (i) => _play(songs, i),
                    ),
                  ),
                LibrarySegment.albums =>
                  _AlbumsBody(miniPlayerVisible: miniPlayerVisible),
                LibrarySegment.artists =>
                  _ArtistsBody(miniPlayerVisible: miniPlayerVisible),
                LibrarySegment.genres =>
                  _GenresBody(miniPlayerVisible: miniPlayerVisible),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally-scrollable pill segment: Songs / Albums / Artists / Genres.
class _SegmentRow extends ConsumerWidget {
  const _SegmentRow({required this.selected});

  final LibrarySegment selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = <(LibrarySegment, String)>[
      (LibrarySegment.songs, l10n.tabSongs),
      (LibrarySegment.albums, l10n.tabAlbums),
      (LibrarySegment.artists, l10n.tabArtists),
      (LibrarySegment.genres, l10n.tabGenres),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, SpacingTokens.sm + 2),
      child: Row(
        children: [
          for (final (seg, label) in items) ...[
            _SegChip(
              label: label,
              selected: seg == selected,
              onTap: () =>
                  ref.read(librarySegmentProvider.notifier).state = seg,
            ),
            if (seg != items.last.$1) const SizedBox(width: SpacingTokens.sm),
          ],
        ],
      ),
    );
  }
}

/// A single pill chip in the Library segment row, styled per the DS Chip.
class _SegChip extends StatelessWidget {
  const _SegChip({
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
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg - 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surfaceElevated,
          borderRadius: RadiusTokens.brPill,
          border: selected
              ? null
              : Border.all(color: colors.divider),
        ),
        child: Text(
          label,
          style: AppTextTheme.body.copyWith(
            color: selected ? colors.onAccent : colors.onSurfaceMuted,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _SongsBody extends ConsumerWidget {
  const _SongsBody({
    required this.songs,
    required this.mode,
    required this.miniPlayerVisible,
    required this.onPlayAt,
  });

  final List<Song> songs;
  final DisplayMode mode;
  final bool miniPlayerVisible;
  final ValueChanged<int> onPlayAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom =
        playerBarInset(context, miniPlayerVisible: miniPlayerVisible);
    final selection = ref.watch(selectionProvider(LibraryPage._listId));
    final notifier = ref.read(selectionProvider(LibraryPage._listId).notifier);
    final selecting = selection.active;
    final orderedIds = [for (final s in songs) s.id];

    void onLongPress(Song song) {
      HapticFeedback.mediumImpact();
      if (selecting) {
        notifier.selectRange(orderedIds, song.id);
      } else {
        notifier.enter(song.id);
      }
    }

    void onTapAt(int i) {
      if (selecting) {
        HapticFeedback.selectionClick();
        notifier.toggle(songs[i].id);
      } else {
        onPlayAt(i);
      }
    }

    bool? selectedOf(Song s) => selecting ? selection.contains(s.id) : null;

    switch (mode) {
      case DisplayMode.list:
        return ListView.builder(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.md, 0, SpacingTokens.md, bottom),
          itemCount: songs.length,
          itemBuilder: (_, i) => SongListTile(
            song: songs[i],
            selected: selectedOf(songs[i]),
            onTap: () => onTapAt(i),
            onLongPress: () => onLongPress(songs[i]),
            onMore: () => showSongActions(context, songs[i]),
          ),
        );
      case DisplayMode.compact:
        return ListView.builder(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.sm, 0, SpacingTokens.sm, bottom),
          itemCount: songs.length,
          itemBuilder: (_, i) => SongCompactTile(
            song: songs[i],
            selected: selectedOf(songs[i]),
            onTap: () => onTapAt(i),
            onLongPress: () => onLongPress(songs[i]),
          ),
        );
      case DisplayMode.grid:
        return GridView.builder(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.lg, 0, SpacingTokens.lg, bottom),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: SpacingTokens.lg,
            crossAxisSpacing: SpacingTokens.lg,
            childAspectRatio: 0.78,
          ),
          itemCount: songs.length,
          itemBuilder: (_, i) => SongGridTile(
            song: songs[i],
            selected: selectedOf(songs[i]),
            onTap: () => onTapAt(i),
            onLongPress: () => onLongPress(songs[i]),
          ),
        );
    }
  }
}

/// Albums grid — mirrors the Albums page body.
class _AlbumsBody extends ConsumerWidget {
  const _AlbumsBody({required this.miniPlayerVisible});

  final bool miniPlayerVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final albumsAsync = ref.watch(albumsProvider);
    final bottom =
        playerBarInset(context, miniPlayerVisible: miniPlayerVisible);
    return AsyncStateView<List<Album>>(
      value: albumsAsync.like,
      isEmpty: (a) => a.isEmpty,
      emptyMessage: l10n.libraryEmpty,
      emptyIcon: Icons.album_outlined,
      onRetry: () => ref.invalidate(songsProvider),
      data: (albums) => GridView.builder(
        padding:
            EdgeInsets.fromLTRB(SpacingTokens.lg, 0, SpacingTokens.lg, bottom),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: SpacingTokens.xl,
          crossAxisSpacing: SpacingTokens.lg,
          childAspectRatio: 0.76,
        ),
        itemCount: albums.length,
        itemBuilder: (_, i) => AlbumGridTile(
          album: albums[i],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AlbumDetailPage(album: albums[i]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Artists list — mirrors the Artists page body.
class _ArtistsBody extends ConsumerWidget {
  const _ArtistsBody({required this.miniPlayerVisible});

  final bool miniPlayerVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final artistsAsync = ref.watch(artistsProvider);
    final bottom =
        playerBarInset(context, miniPlayerVisible: miniPlayerVisible);
    return AsyncStateView<List<Artist>>(
      value: artistsAsync.like,
      isEmpty: (a) => a.isEmpty,
      emptyMessage: l10n.libraryEmpty,
      emptyIcon: Icons.person_outline,
      onRetry: () => ref.invalidate(songsProvider),
      data: (artists) => ListView.builder(
        padding:
            EdgeInsets.fromLTRB(SpacingTokens.md, 0, SpacingTokens.md, bottom),
        itemCount: artists.length,
        itemBuilder: (_, i) {
          final a = artists[i];
          final subtitle =
              '${l10n.albumsCount(a.albumCount)} · ${l10n.songsCount(a.songCount)}';
          return ArtistListTile(
            artist: a,
            subtitle: subtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ArtistDetailPage(artist: a),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Genres list — mirrors the Genres page body.
class _GenresBody extends ConsumerWidget {
  const _GenresBody({required this.miniPlayerVisible});

  final bool miniPlayerVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final genresAsync = ref.watch(genresProvider);
    final bottom =
        playerBarInset(context, miniPlayerVisible: miniPlayerVisible);
    return AsyncStateView<List<Genre>>(
      value: genresAsync.like,
      isEmpty: (g) => g.isEmpty,
      emptyMessage: l10n.libraryEmpty,
      emptyIcon: Icons.category_outlined,
      onRetry: () => ref.invalidate(songsProvider),
      data: (genres) => ListView.builder(
        padding:
            EdgeInsets.fromLTRB(SpacingTokens.md, 0, SpacingTokens.md, bottom),
        itemCount: genres.length,
        itemBuilder: (_, i) {
          final g = genres[i];
          return GenreListTile(
            genre: g,
            subtitle: l10n.songsCount(g.songCount),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GenreDetailPage(genre: g),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The "For You" section — a horizontal rail of intelligent collection cards
/// (Your Mix, Heavy Rotation, Hidden Gems, Rediscover, an artist deep-cut).
/// Everything here is ephemeral; a card is only persisted if the user taps its
/// save badge to add it to their playlists.
class _ForYouSection extends ConsumerWidget {
  const _ForYouSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(smartCollectionsProvider);
    if (collections.isEmpty) return const SizedBox(width: double.infinity);
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 2),
          child: Text(
            'For You',
            style: AppTextTheme.display.copyWith(
              color: colors.onSurface,
              fontSize: 21,
              letterSpacing: -0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: collections.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) => _CollectionCard(collection: collections[i]),
          ),
        ),
      ],
    );
  }
}

/// One "For You" card: a 2×2 cover mosaic with a kind glyph, a teal play disc,
/// and a glass save badge, over a title + subtitle. Tapping the body plays the
/// collection; tapping the badge saves it to the user's playlists.
class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.collection});

  final SmartCollection collection;

  static const double _w = 172;

  IconData get _kindIcon => switch (collection.kind) {
        SmartCollectionKind.forYou => Icons.auto_awesome,
        SmartCollectionKind.heavyRotation => Icons.local_fire_department_rounded,
        SmartCollectionKind.hiddenGems => Icons.diamond_outlined,
        SmartCollectionKind.rediscover => Icons.history_rounded,
        SmartCollectionKind.artist => Icons.person_rounded,
      };

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(playlistRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final created = await repo.create(collection.title);
    await repo.addSongs(created.id, collection.songIds);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved "${collection.title}" to your playlists'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _play(WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(audioControllerProvider).playQueue(collection.songs, startIndex: 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final songs = collection.songs;
    return PressScale(
      onTap: () => _play(ref),
      pressedScale: 0.97,
      semanticLabel: collection.title,
      child: SizedBox(
        width: _w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover mosaic + overlays.
            SizedBox(
              width: _w,
              height: _w,
              child: Stack(
                children: [
                  // 2×2 mosaic of the first four covers.
                  ClipRRect(
                    borderRadius: RadiusTokens.brLg,
                    child: Column(
                      children: [
                        for (var row = 0; row < 2; row++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var col = 0; col < 2; col++)
                                  Expanded(
                                    child: _MosaicTile(
                                        song: songs[(row * 2 + col) % songs.length]),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Crisp inner hairline for a glass-edge feel.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: RadiusTokens.brLg,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08), width: 1),
                        ),
                      ),
                    ),
                  ),
                  // Kind glyph — a small dark chip, top-left.
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _GlyphChip(icon: _kindIcon),
                  ),
                  // Save badge — glass "+", top-right.
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _save(context, ref),
                      child: _GlyphChip(icon: Icons.add_rounded),
                    ),
                  ),
                  // Teal play disc, bottom-right.
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withOpacity(0.42),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(Icons.play_arrow_rounded,
                          color: colors.onAccent, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextTheme.body.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              collection.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single cover tile inside a collection mosaic (square, seamless).
class _MosaicTile extends StatelessWidget {
  const _MosaicTile({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: AuraArtwork(
        seed: song.artworkSeed,
        fill: true,
        borderRadius: BorderRadius.zero,
        hasArtwork: song.hasArtwork,
        artworkId: int.tryParse(song.id),
      ),
    );
  }
}

/// A small rounded dark chip holding a single glyph (kind marker / save badge).
class _GlyphChip extends StatelessWidget {
  const _GlyphChip({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.14), width: 0.5),
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.92), size: 17),
    );
  }
}
