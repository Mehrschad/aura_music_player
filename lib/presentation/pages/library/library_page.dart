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
import '../../providers/discovery_prefs_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/selection_providers.dart';
import '../../providers/smart_collections_provider.dart';
import '../../providers/taste_providers.dart';
import '../../providers/top_charts_provider.dart';
import '../../providers/weekly_recap_provider.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/library/album_grid_tile.dart';
import '../../widgets/library/artist_list_tile.dart';
import '../../widgets/library/collection_actions.dart';
import '../../widgets/library/collection_cover.dart';
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
import 'collection_detail_page.dart';

/// Hour-of-day greeting for the home header.
String _greetingFor(int hour) {
  if (hour < 5) return 'Good night';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 22) return 'Good evening';
  return 'Good night';
}

const List<String> _kWeekdays = [
  'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'
];
const List<String> _kMonths = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
];

/// Compact date label, e.g. "SAT · 28 JUN".
String _dateLabel(DateTime d) =>
    '${_kWeekdays[d.weekday - 1]} · ${d.day} ${_kMonths[d.month - 1]}';

/// Shared monospace label style for the home's small-caps eyebrows/labels —
/// the type system's "machine voice" for dates, counts and section tags.
TextStyle _monoLabel(Color color, {double size = 11, double spacing = 1.6}) =>
    TextStyle(
      fontFamily: 'monospace',
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: spacing,
    );

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

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.onSurfaceMuted),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
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

    // Time-aware header: a greeting that shifts with the hour, over today's
    // date — a living, personal home rather than a static wordmark.
    final now = DateTime.now();
    final greeting = _greetingFor(now.hour);
    final dateLabel = _dateLabel(now);

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        // Only the page's *vertical* scroll drives the collapse — ignore the
        // horizontal "For You" / shelf rails, which otherwise made the header
        // and shelves vanish as you swiped a rail sideways.
        if (n.metrics.axis != Axis.vertical) return false;
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
                                    fontSize: 30,
                                    height: 1.0,
                                    letterSpacing: -1.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                            child: Text(
                              greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // A single overflow menu holds sort / folders /
                        // settings — the dedicated grid-toggle and folder icons
                        // are gone for a cleaner header.
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: colors.onSurface),
                          onSelected: (v) {
                            if (v == 'sort') {
                              showSortSheet(
                                context,
                                current: sort,
                                onChanged: (s) => ref
                                    .read(librarySortProvider.notifier)
                                    .state = s,
                              );
                            } else if (v == 'folders') {
                              openFolderBrowser(context);
                            } else if (v == 'settings') {
                              openSettings(context);
                            }
                          },
                          itemBuilder: (_) => [
                            _menuItem('sort', Icons.sort, l10n.sortLabel),
                            _menuItem(
                                'folders', Icons.folder_outlined, l10n.folders),
                            _menuItem('settings', Icons.settings_outlined,
                                l10n.settings),
                          ],
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
                              dateLabel,
                              style: _monoLabel(colors.onSurfaceFaint),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

    // The content sliver depends on the display mode.
    final Widget contentSliver;
    switch (mode) {
      case DisplayMode.list:
        contentSliver = SliverPadding(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.md, 0, SpacingTokens.md, bottom),
          sliver: SliverList.builder(
            itemCount: songs.length,
            itemBuilder: (_, i) => SongListTile(
              song: songs[i],
              selected: selectedOf(songs[i]),
              onTap: () => onTapAt(i),
              onLongPress: () => onLongPress(songs[i]),
              onMore: () => showSongActions(context, songs[i]),
            ),
          ),
        );
      case DisplayMode.compact:
        contentSliver = SliverPadding(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.sm, 0, SpacingTokens.sm, bottom),
          sliver: SliverList.builder(
            itemCount: songs.length,
            itemBuilder: (_, i) => SongCompactTile(
              song: songs[i],
              selected: selectedOf(songs[i]),
              onTap: () => onTapAt(i),
              onLongPress: () => onLongPress(songs[i]),
            ),
          ),
        );
      case DisplayMode.grid:
        contentSliver = SliverPadding(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.lg, 0, SpacingTokens.lg, bottom),
          sliver: SliverGrid.builder(
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
          ),
        );
    }

    // The discovery rails (For You + Top Artists/Tracks/Albums) lead the scroll
    // so they scroll away naturally into the song list. Hidden while selecting.
    return CustomScrollView(
      slivers: [
        if (!selecting)
          const SliverToBoxAdapter(child: _DiscoveryHeader()),
        contentSliver,
      ],
    );
  }
}

/// The home discovery rails shown above the song list: the "For You" smart
/// collections, then the user's Top Artists, Top Tracks and Top Albums.
class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColdStartCard(),
        _JumpBackInShelf(),
        _ForYouSection(),
        _OnThisDayShelf(),
        _WeeklyRecapCard(),
        _SuggestedArtistsBox(),
        _TopArtistsShelf(),
        _TopTracksShelf(),
        _TopAlbumsShelf(),
        SizedBox(height: SpacingTokens.sm),
      ],
    );
  }
}

/// Cold-start guidance: shown until the taste model has enough data, in place
/// of an empty "For You". A friendly nudge + a progress bar toward unlocking
/// personal mixes.
class _ColdStartCard extends ConsumerWidget {
  const _ColdStartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
    if (songs.isEmpty) return const SizedBox.shrink();
    final profile = ref.watch(tasteProfileProvider);
    if (profile.playCount >= kMinPlaysForRecommendations) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    final progress =
        (profile.playCount / kMinPlaysForRecommendations).clamp(0.0, 1.0);
    final remaining = kMinPlaysForRecommendations - profile.playCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brLg,
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Text(
                  'Unlock your For You',
                  style: AppTextTheme.title.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              remaining == 1
                  ? 'Play 1 more track and Aura starts building mixes from your taste.'
                  : 'Play $remaining more tracks and Aura starts building mixes from your taste.',
              style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
            ),
            const SizedBox(height: SpacingTokens.md),
            ClipRRect(
              borderRadius: RadiusTokens.brPill,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${profile.playCount} / $kMinPlaysForRecommendations plays',
              style: _monoLabel(colors.onSurfaceFaint, size: 10, spacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Jump back in" — quick-resume rail of the most recently played tracks.
class _JumpBackInShelf extends ConsumerWidget {
  const _JumpBackInShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(jumpBackInProvider);
    if (recents.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader('Jump back in'),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) {
              final s = recents[i];
              return PressScale(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(audioControllerProvider)
                      .playQueue(recents, startIndex: i);
                },
                pressedScale: 0.97,
                semanticLabel: s.title,
                child: SizedBox(
                  width: 124,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuraArtwork(
                        seed: s.artworkSeed,
                        size: 124,
                        borderRadius: RadiusTokens.brMd,
                        hasArtwork: s.hasArtwork,
                        artworkId: int.tryParse(s.id),
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.body.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        s.artist,
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

/// Shared section header for a discovery rail.
class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, 2),
      child: Text(
        title,
        style: AppTextTheme.display.copyWith(
          color: context.colors.onSurface,
          fontSize: 21,
          letterSpacing: -0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Top Artists rail — circular avatars from the user's most-played artists.
class _TopArtistsShelf extends ConsumerWidget {
  const _TopArtistsShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(topArtistsProvider);
    if (artists.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader('Top Artists'),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) {
              final a = artists[i];
              return PressScale(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArtistDetailPage(artist: a),
                  ),
                ),
                pressedScale: 0.96,
                semanticLabel: a.name,
                child: SizedBox(
                  width: 92,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: AuraArtwork(
                          seed: a.artworkSeed,
                          size: 88,
                          borderRadius: BorderRadius.circular(44),
                          hasArtwork: a.hasArtwork,
                          artworkId: a.firstSongId,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.name,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.caption.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
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

/// Top Tracks rail — most-played songs; tapping plays from that track.
class _TopTracksShelf extends ConsumerWidget {
  const _TopTracksShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(topTracksProvider);
    if (tracks.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader('Top Tracks'),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) {
              final s = tracks[i];
              return PressScale(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(audioControllerProvider)
                      .playQueue(tracks, startIndex: i);
                },
                pressedScale: 0.97,
                semanticLabel: s.title,
                child: SizedBox(
                  width: 124,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuraArtwork(
                        seed: s.artworkSeed,
                        size: 124,
                        borderRadius: RadiusTokens.brMd,
                        hasArtwork: s.hasArtwork,
                        artworkId: int.tryParse(s.id),
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.body.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        s.artist,
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

/// Top Albums rail — most-played albums; tapping opens the album.
class _TopAlbumsShelf extends ConsumerWidget {
  const _TopAlbumsShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(topAlbumsProvider);
    if (albums.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader('Top Albums'),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) {
              final a = albums[i];
              return PressScale(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlbumDetailPage(album: a),
                  ),
                ),
                pressedScale: 0.97,
                semanticLabel: a.name,
                child: SizedBox(
                  width: 124,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuraArtwork(
                        seed: a.artworkSeed,
                        size: 124,
                        borderRadius: RadiusTokens.brMd,
                        hasArtwork: a.hasArtwork,
                        artworkId: a.firstSongId,
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.body.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        a.artist,
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

    // How long until the 3-day mix rotates (matches taste_providers' daySeed).
    final daysIntoWindow =
        DateTime.now().difference(DateTime(2020)).inDays % 3;
    final daysLeft = 3 - daysIntoWindow;
    final refreshLabel =
        daysLeft <= 1 ? 'Refreshes tomorrow' : 'Refreshes in $daysLeft days';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'For You',
                style: AppTextTheme.display.copyWith(
                  color: colors.onSurface,
                  fontSize: 21,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                refreshLabel,
                style: AppTextTheme.caption.copyWith(
                  color: colors.onSurfaceFaint,
                ),
              ),
            ],
          ),
        ),
        const _DiscoveryBalanceSlider(),
        SizedBox(
          height: 188,
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

/// The "Familiar ↔ New" balance slider under the For You header — biases the
/// recommendation engine toward well-worn favourites or fresh discovery.
class _DiscoveryBalanceSlider extends ConsumerWidget {
  const _DiscoveryBalanceSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bias = ref.watch(discoveryBalanceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, 0, SpacingTokens.lg, 0),
      child: Row(
        children: [
          Text('FAMILIAR', style: _monoLabel(colors.onSurfaceFaint, size: 9)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: colors.accent,
                inactiveTrackColor: colors.divider,
                thumbColor: colors.accent,
                overlayColor: colors.accent.withOpacity(0.18),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: bias,
                onChanged: (v) =>
                    ref.read(discoveryBalanceProvider.notifier).state = v,
              ),
            ),
          ),
          Text('NEW', style: _monoLabel(colors.onSurfaceFaint, size: 9)),
        ],
      ),
    );
  }
}

/// "On this day" — a nostalgic rail of tracks the user played around this date
/// in past years. Hidden when there isn't enough history.
class _OnThisDayShelf extends ConsumerWidget {
  const _OnThisDayShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(onThisDayProvider);
    if (songs.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader('On this day'),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) {
              final s = songs[i];
              return PressScale(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(audioControllerProvider)
                      .playQueue(songs, startIndex: i);
                },
                pressedScale: 0.97,
                semanticLabel: s.title,
                child: SizedBox(
                  width: 124,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuraArtwork(
                        seed: s.artworkSeed,
                        size: 124,
                        borderRadius: RadiusTokens.brMd,
                        hasArtwork: s.hasArtwork,
                        artworkId: int.tryParse(s.id),
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.body.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        s.artist,
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

/// One "For You" card: the generated solid-colour [CollectionCover] with a teal
/// play disc. Tapping the body opens the collection (its song list); tapping the
/// disc plays it straight away without leaving the home.
class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.collection});

  final SmartCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return PressScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CollectionDetailPage(collection: collection),
        ),
      ),
      onLongPress: () => showCollectionQuickActions(context, ref, collection),
      pressedScale: 0.97,
      semanticLabel: collection.title,
      child: SizedBox(
        width: 172,
        height: 172,
        child: Stack(
          children: [
            Positioned.fill(child: CollectionCover(collection: collection)),
            Positioned(
              right: 10,
              bottom: 10,
              child: PressScale(
                pressedScale: 0.84,
                semanticLabel: 'Play ${collection.title}',
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(audioControllerProvider)
                      .playQueue(collection.songs, startIndex: 0);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      color: colors.onAccent, size: 26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Your week in music" — a mini wrapped: a boxed recap of the last 7 days.
class _WeeklyRecapCard extends ConsumerWidget {
  const _WeeklyRecapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recap = ref.watch(weeklyRecapProvider);
    if (!recap.hasData) return const SizedBox.shrink();
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brLg,
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 16, color: colors.accent),
                const SizedBox(width: 8),
                Text('YOUR WEEK',
                    style: _monoLabel(colors.onSurfaceMuted, spacing: 1.8)),
              ],
            ),
            const SizedBox(height: SpacingTokens.md),
            Row(
              children: [
                _RecapStat(value: '${recap.plays}', label: 'PLAYS'),
                _RecapStat(value: '${recap.minutes}', label: 'MINUTES'),
                _RecapStat(
                    value: '${recap.distinctArtists}', label: 'ARTISTS'),
              ],
            ),
            if (recap.topArtist != null) ...[
              const SizedBox(height: SpacingTokens.md),
              Text(
                'Most played · ${recap.topArtist}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One big-number stat inside the weekly recap card.
class _RecapStat extends StatelessWidget {
  const _RecapStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              color: colors.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: _monoLabel(colors.onSurfaceFaint, size: 9)),
        ],
      ),
    );
  }
}

/// "Suggested Artists" — a visually distinct boxed rail of artists the taste
/// engine recommends (discovery, not the user's already-top artists). Hidden
/// until recommendations exist.
class _SuggestedArtistsBox extends ConsumerWidget {
  const _SuggestedArtistsBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(suggestedArtistsProvider);
    if (artists.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brLg,
          border: Border.all(color: colors.divider),
        ),
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: colors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Suggested Artists',
                    style: AppTextTheme.title.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
                itemCount: artists.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: SpacingTokens.md),
                itemBuilder: (_, i) {
                  final a = artists[i];
                  return PressScale(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ArtistDetailPage(artist: a),
                      ),
                    ),
                    pressedScale: 0.96,
                    semanticLabel: a.name,
                    child: SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: AuraArtwork(
                              seed: a.artworkSeed,
                              size: 72,
                              borderRadius: BorderRadius.circular(36),
                              hasArtwork: a.hasArtwork,
                              artworkId: a.firstSongId,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.name,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextTheme.caption.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
