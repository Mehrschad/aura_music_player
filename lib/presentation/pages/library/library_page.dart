import 'dart:async';

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
import '../../../domain/models/playlist.dart';
import '../../../domain/models/song.dart';
import '../../providers/async_value_x.dart';
import '../../../domain/taste/smart_collection.dart';
import '../../providers/discovery_prefs_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../../providers/selection_providers.dart';
import '../../providers/smart_collections_provider.dart';
import '../../providers/taste_providers.dart';
import '../../providers/top_charts_provider.dart';
import '../../providers/top_picks_provider.dart';
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
import '../playlists/playlist_detail_page.dart';
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

/// The home title that gently alternates between the time-aware greeting and
/// the "Aura" wordmark every dozen seconds, so the header feels alive rather
/// than static. It inherits its animated, scroll-driven text style from the
/// surrounding [AnimatedDefaultTextStyle]; reduce-motion shows the greeting
/// plainly.
class _CyclingTitle extends StatefulWidget {
  const _CyclingTitle({required this.greeting});

  final String greeting;

  @override
  State<_CyclingTitle> createState() => _CyclingTitleState();
}

class _CyclingTitleState extends State<_CyclingTitle> {
  static const Duration _interval = Duration(seconds: 12);
  Timer? _timer;
  bool _showAura = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) {
      if (mounted) setState(() => _showAura = !_showAura);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(widget.greeting,
          maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final text = _showAura ? 'Aura' : widget.greeting;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Keep both the outgoing and incoming title anchored to the left corner
      // (the default centres them, which made the text drift mid-animation).
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.centerLeft,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.28),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        text,
        key: ValueKey<String>(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

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
                            child: _CyclingTitle(greeting: greeting),
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
        _PinnedRail(),
        _TopPicksGrid(),
        _ForYouSection(),
        _OnThisDayShelf(),
        _YourPlaylistsRail(),
        _QuickPlaylistsRail(),
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

/// "Top Picks" — a compact 2-column grid of quick-access shortcuts right under
/// the header (recent, your mix, a time-aware mood, heavy rotation, favourites,
/// on this day). Tiles fade + rise in on a gentle stagger the first time the
/// home appears. Tapping a tile plays its list straight away.
class _TopPicksGrid extends ConsumerStatefulWidget {
  const _TopPicksGrid();

  @override
  ConsumerState<_TopPicksGrid> createState() => _TopPicksGridState();
}

class _TopPicksGridState extends ConsumerState<_TopPicksGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 660),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picks = ref.watch(topPicksProvider);
    if (picks.isEmpty) return const SizedBox.shrink();
    if (MediaQuery.disableAnimationsOf(context)) _ctrl.value = 1.0;

    final rows = <Widget>[];
    for (var i = 0; i < picks.length; i += 2) {
      final hasRight = i + 1 < picks.length;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
        child: Row(
          children: [
            Expanded(child: _animated(picks[i], i)),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child:
                  hasRight ? _animated(picks[i + 1], i + 1) : const SizedBox(),
            ),
          ],
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _animated(TopPick pick, int i) {
    final start = (i * 0.09).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.20),
          end: Offset.zero,
        ).animate(anim),
        child: _PickTile(
          pick: pick,
          onTap: () {
            HapticFeedback.selectionClick();
            ref
                .read(audioControllerProvider)
                .playQueue(pick.songs, startIndex: 0);
          },
        ),
      ),
    );
  }
}

/// One Top-Picks tile: a cover (or accent glyph) flush-left of a bold label.
class _PickTile extends StatelessWidget {
  const _PickTile({required this.pick, required this.onTap});

  final TopPick pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cover = pick.cover;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.96,
      semanticLabel: pick.title,
      // ClipRRect (rather than a bordered Container) guarantees clean, even
      // corners — the cover on the left is clipped to the same radius.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: colors.surfaceElevated,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: cover != null
                      ? AuraArtwork(
                          seed: cover.artworkSeed,
                          fill: true,
                          borderRadius: BorderRadius.zero,
                          hasArtwork: cover.hasArtwork,
                          artworkId: int.tryParse(cover.id),
                        )
                      : ColoredBox(
                          color: colors.accent.withOpacity(0.18),
                          child:
                              Icon(pick.icon, color: colors.accent, size: 22),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      pick.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.body.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

/// "Pinned" — collections the user pinned, floated to the top in their own
/// rail (and removed from For You so they're not shown twice). Hidden when no
/// pins resolve to a current collection.
class _PinnedRail extends ConsumerWidget {
  const _PinnedRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(pinnedCollectionsProvider);
    if (pinned.isEmpty) return const SizedBox.shrink();
    final collections = ref.watch(smartCollectionsProvider);
    final items = [for (final c in collections) if (pinned.contains(c.id)) c];
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, 2),
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                'Pinned',
                style: AppTextTheme.display.copyWith(
                  color: colors.onSurface,
                  fontSize: 21,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) => _CollectionCard(collection: items[i]),
          ),
        ),
      ],
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
    final all = ref.watch(smartCollectionsProvider);
    // Pinned collections live in their own rail above — drop them here.
    final pinned = ref.watch(pinnedCollectionsProvider);
    final collections = pinned.isEmpty
        ? all
        : [for (final c in all) if (!pinned.contains(c.id)) c];
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
            Positioned.fill(child: CollectionCover.collection(collection)),
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

/// "Your Playlists" — the user's own playlists, as solid mono covers.
class _YourPlaylistsRail extends ConsumerWidget {
  const _YourPlaylistsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists =
        ref.watch(playlistsProvider).valueOrNull ?? const <Playlist>[];
    if (playlists.isEmpty) return const SizedBox.shrink();
    final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
    final byId = <String, Song>{for (final s in songs) s.id: s};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader('Your Playlists'),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) {
              final p = playlists[i];
              final first = p.songIds.isEmpty ? null : byId[p.songIds.first];
              return PressScale(
                onTap: () => openUserPlaylist(context, p.id),
                pressedScale: 0.97,
                semanticLabel: p.name,
                child: CollectionCover.label(
                  title: p.name,
                  count: p.songIds.length,
                  icon: Icons.queue_music_rounded,
                  colorSeed: p.id,
                  artSeed: first?.artworkSeed,
                  hasArtwork: first?.hasArtwork ?? false,
                  artworkId: first == null ? null : int.tryParse(first.id),
                  size: 172,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// "Quick Playlists" — the built-in auto playlists. Only the ones that actually
/// have tracks are shown (so no empty cards), each with its real count, and any
/// two that resolve to the same tracks are de-duplicated.
class _QuickPlaylistsRail extends ConsumerWidget {
  const _QuickPlaylistsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final specs = <(AutoPlaylist, String, IconData)>[
      (AutoPlaylist.mostPlayed, l10n.autoMostPlayed,
          Icons.local_fire_department_rounded),
      (AutoPlaylist.recentlyAdded, l10n.autoRecentlyAdded,
          Icons.fiber_new_rounded),
      (AutoPlaylist.recentlyPlayed, l10n.autoRecentlyPlayed,
          Icons.history_rounded),
      (AutoPlaylist.favorites, l10n.autoFavorites, Icons.favorite_rounded),
      (AutoPlaylist.topRated, l10n.autoTopRated, Icons.star_rounded),
    ];

    final tiles = <(AutoPlaylist, String, IconData, int, Song)>[];
    final seen = <String>{};
    for (final (type, label, icon) in specs) {
      final songs =
          ref.watch(autoPlaylistSongsProvider(type)).valueOrNull ??
              const <Song>[];
      if (songs.isEmpty) continue;
      // De-dupe: skip any auto playlist that resolves to the same track set as
      // one already shown.
      final sig =
          '${songs.length}:${songs.take(20).map((s) => s.id).join('|')}';
      if (!seen.add(sig)) continue;
      tiles.add((type, label, icon, songs.length, songs.first));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader('Quick Playlists'),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg, SpacingTokens.sm, SpacingTokens.lg, 0),
            itemCount: tiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.md),
            itemBuilder: (_, i) {
              final (type, label, icon, count, first) = tiles[i];
              return PressScale(
                onTap: () => openAutoPlaylist(context, type),
                pressedScale: 0.97,
                semanticLabel: label,
                child: CollectionCover.label(
                  title: label,
                  count: count,
                  icon: icon,
                  colorSeed: 'auto_${type.name}',
                  artSeed: first.artworkSeed,
                  hasArtwork: first.hasArtwork,
                  artworkId: int.tryParse(first.id),
                  size: 172,
                ),
              );
            },
          ),
        ),
      ],
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
