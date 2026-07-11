import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/library/song_tree.dart';
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
import '../../widgets/library/now_playing_indicator.dart';
import '../../widgets/library/selection_bar.dart';
import '../../widgets/library/song_compact_tile.dart';
import '../../widgets/library/song_grid_tile.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/press_scale.dart';
import '../../shell/nav_provider.dart';
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

/// Decoration for the home's boxed discovery panels (Your Week, Suggested
/// Artists, the cold-start nudge). On the AMOLED theme the elevated surface is
/// almost pure black and its divider-hairline vanishes, so we lift the fill a
/// few percent and give it a clearly visible border — the card then reads as a
/// distinct panel rather than a shape lost in the background.
BoxDecoration _discoveryCardDecoration(AppColors colors) => BoxDecoration(
      color:
          Color.alphaBlend(Colors.white.withOpacity(0.03), colors.surfaceElevated),
      borderRadius: RadiusTokens.brLg,
      border: Border.all(color: colors.onSurface.withOpacity(0.08)),
    );

/// Fixed row heights for the flat library lists. Pinning these lets the list
/// use a [SliverFixedExtentList] — so a scrubber jump (or a tab switch that
/// preserves a deep offset) is O(1) instead of forcing Flutter to build every
/// intervening row, which is what made huge libraries hitch. They're driven by
/// the leading artwork/avatar, so they stay stable across text scales.
const double _kSongRowExtent = 66; // 48 art + 8·2 pad + 1·2 margin
const double _kArtistRowExtent = 72; // 56 avatar + 8·2 pad

// Fixed heights for the tree (folded Songs) rows. Pinning them keeps the A–Z
// scrubber's offset maths exact: a letter jump is `discovery + Σ heights of the
// rows above its header`, so it never has to build intervening rows.
const double _kLetterHeaderExtent = 44; // section letter divider
const double _kArtistHeaderExtent = 62; // 46 avatar + 8·2 pad
const double _kAlbumHeaderExtent = 60; // 44 artwork + 8·2 pad
const double _kTreeSongExtent = 52; // 40 artwork/number, centred

/// Row height for a folded-tree row of [kind].
double _treeRowExtent(LibRowKind kind) => switch (kind) {
      LibRowKind.letter => _kLetterHeaderExtent,
      LibRowKind.artist => _kArtistHeaderExtent,
      LibRowKind.album => _kAlbumHeaderExtent,
      LibRowKind.song => _kTreeSongExtent,
    };

/// Left gutter and per-level indent for the tree's VS-Code-style guide lines.
const double _kTreeGutter = SpacingTokens.md;
const double _kIndentStep = 20;

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

  // True once the discovery rails have scrolled away and the tab bar is pinned
  // at the top — only then is the A-Z scrubber shown, so it never floats over
  // the rails at rest.
  bool _tabsPinned = false;

  // The single page scroll, driven by the A-Z scrubber's jumps.
  final ScrollController _scrollController = ScrollController();

  // Measures the discovery header's height so the scrubber can translate a
  // letter into an exact scroll offset (discovery sits above the pinned tabs).
  final GlobalKey _discoveryKey = GlobalKey();
  double _discoveryExtent = 0;

  // Cumulative pixel offset of each folded-tree row from the top of the songs
  // sliver, or null when the Songs list isn't folded. Recomputed in build from
  // the fixed per-kind heights so an A–Z jump into the tree lands exactly.
  List<double>? _songRowOffsets;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// After each frame, cache the discovery header's measured height while it's
  /// still mounted, so a scrubber jump made after scrolling deep still lands
  /// accurately (the value is stable until the rails' data changes).
  void _scheduleDiscoveryMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _discoveryKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.size.height > 0) {
        _discoveryExtent = box.size.height;
      }
    });
  }

  /// Scrolls so the [index]-th item of [segment]/[mode] rests just beneath the
  /// pinned tab bar. Items in a segment share a fixed height, so the offset is
  /// `discovery + index·extent` (the pinned bar's own extent cancels out).
  void _jumpToItem({
    required LibrarySegment segment,
    required int index,
    required double viewportWidth,
  }) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    double target;
    if (segment == LibrarySegment.songs && _songRowOffsets != null) {
      // Folded Songs tree: [index] is a *row* index; jump to its exact offset.
      final offsets = _songRowOffsets!;
      final off =
          (index >= 0 && index < offsets.length) ? offsets[index] : 0.0;
      target = _discoveryExtent + off;
    } else if (segment == LibrarySegment.albums) {
      final tileW =
          (viewportWidth - 2 * SpacingTokens.lg - SpacingTokens.lg) / 2;
      final rowExtent = tileW / 0.76 + SpacingTokens.xl;
      target = _discoveryExtent + SpacingTokens.md + (index ~/ 2) * rowExtent;
    } else {
      final extent = segment == LibrarySegment.artists
          ? _kArtistRowExtent
          : _kSongRowExtent;
      target = _discoveryExtent + index * extent;
    }
    _scrollController.jumpTo(target.clamp(0.0, max));
  }

  /// Smoothly returns the page to the very top (the "back to top" button).
  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    HapticFeedback.selectionClick();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  /// Builds the A–Z model for [segment], or null when a scrubber doesn't apply
  /// (Genres, non-alphabetical song sorts, or too few items to be worth it).
  _Alphabet? _alphabetFor(
    LibrarySegment segment,
    DisplayMode mode,
    LibrarySort sort,
    List<Song> allSongs,
  ) {
    const int threshold = 24;
    final List<String> keys;
    switch (segment) {
      case LibrarySegment.songs:
        // The Songs list only carries a scrubber when it's folded into a tree
        // (Title/Album/Artist ascending, list mode). The scrubber then jumps to
        // section *headers* rather than raw song indices.
        final tree = ref.watch(songTreeProvider);
        if (tree == null || tree.orderedSongs.length < threshold) return null;
        return _Alphabet.fromLetterRows(tree.letterFirstRow);
      case LibrarySegment.albums:
        final albums = ref.watch(albumsProvider).valueOrNull ?? const <Album>[];
        keys = [for (final a in albums) a.name];
      case LibrarySegment.artists:
        final artists =
            ref.watch(artistsProvider).valueOrNull ?? const <Artist>[];
        keys = [for (final a in artists) a.name];
      case LibrarySegment.genres:
        return null;
    }
    if (keys.length < threshold) return null;
    return _Alphabet.fromKeys(keys);
  }

  void _play(List<Song> queue, int index) {
    ref.read(audioControllerProvider).playQueue(queue, startIndex: index);
  }

  /// The sliver that renders the currently-selected segment's content. Returned
  /// as a sliver (not a box body) so it lives in the page's single
  /// [CustomScrollView] beneath the pinned tab bar — no nested scroll view.
  Widget _segmentSliver({
    required LibrarySegment segment,
    required AsyncValue<List<Song>> songsAsync,
    required DisplayMode mode,
    required SongTreeData? tree,
    required bool miniPlayerVisible,
  }) {
    switch (segment) {
      case LibrarySegment.songs:
        return _SongsSliver(
          songsAsync: songsAsync,
          mode: mode,
          tree: tree,
          miniPlayerVisible: miniPlayerVisible,
          onPlay: _play,
        );
      case LibrarySegment.albums:
        return _AlbumsSliver(miniPlayerVisible: miniPlayerVisible);
      case LibrarySegment.artists:
        return _ArtistsSliver(miniPlayerVisible: miniPlayerVisible);
      case LibrarySegment.genres:
        return _GenresSliver(miniPlayerVisible: miniPlayerVisible);
    }
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
    // The folded Songs tree (null unless the sort folds). Cache each row's pixel
    // offset so the A–Z scrubber can jump into it without building rows.
    final songTree = ref.watch(songTreeProvider);
    if (songTree != null) {
      final offsets = <double>[];
      var acc = 0.0;
      for (final r in songTree.rows) {
        offsets.add(acc);
        acc += _treeRowExtent(r.kind);
      }
      _songRowOffsets = offsets;
    } else {
      _songRowOffsets = null;
    }
    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final selecting = ref.watch(
        selectionProvider(LibraryPage._listId).select((s) => s.active));
    final allSongs = songsAsync.valueOrNull ?? const <Song>[];

    // When the discovery rails are collapsed the browser sits directly under the
    // header, so the tabs pin from the very top.
    final discoveryCollapsed = ref.watch(discoveryCollapsedProvider);
    final showDiscovery = !selecting && !discoveryCollapsed;
    // With no discovery rails above them the tabs are pinned from the start, so
    // the A–Z scrubber should be available immediately rather than waiting for
    // the (absent) rails to scroll away.
    final tabsPinned = _tabsPinned || !showDiscovery;

    // Keep the discovery height measured so scrubber jumps stay accurate; when
    // it isn't shown its extent is zero (the widget isn't in the tree to
    // measure, so pin the value here).
    if (showDiscovery) {
      _scheduleDiscoveryMeasure();
    } else {
      _discoveryExtent = 0;
    }

    // A-Z fast-scroll model for the active alphabetical segment (Songs sorted
    // A–Z in list mode, Artists, Albums). Null hides the scrubber.
    final _Alphabet? alphabet =
        selecting ? null : _alphabetFor(segment, mode, sort, allSongs);

    // "Back to top" sits beside the shrunk mini player — it appears once the
    // page is scrolled down (the same signal that collapses the mini player),
    // so it only shows when there's room beside the centred capsule.
    final navMinimized = ref.watch(navMinimizedProvider);
    final showToTop =
        !selecting && navMinimized && _scrolled && miniPlayerVisible;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

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
        final px = n.metrics.pixels;
        final scrolled = px > 20;
        // The tab bar pins once the discovery rails have fully scrolled past;
        // only then reveal the scrubber so it never overlaps the rails.
        final pinned = _discoveryExtent > 0 && px >= _discoveryExtent - 4;
        // Only flip state on a real threshold crossing — never per pixel.
        if (scrolled != _scrolled || pinned != _tabsPinned) {
          setState(() {
            _scrolled = scrolled;
            _tabsPinned = pinned;
          });
        }
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
                                    .update(s),
                              );
                            } else if (v == 'discovery') {
                              ref
                                  .read(discoveryCollapsedProvider.notifier)
                                  .toggle();
                            } else if (v == 'folders') {
                              openFolderBrowser(context);
                            } else if (v == 'settings') {
                              openSettings(context);
                            }
                          },
                          itemBuilder: (_) => [
                            _menuItem('sort', Icons.sort, l10n.sortLabel),
                            _menuItem(
                              'discovery',
                              discoveryCollapsed
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              discoveryCollapsed
                                  ? 'Show discovery'
                                  : 'Hide discovery',
                            ),
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
            // One unified scroll for the whole page. The discovery rails lead,
            // then the Songs/Albums/Artists/Genres tabs **pin** below them, and
            // the selected segment's content scrolls under the pinned tabs. The
            // discovery header is the same sliver regardless of segment, so
            // switching tabs never tears it down — it stays put while only the
            // content sliver below the tabs swaps.
            Expanded(
              child: Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (showDiscovery)
                        SliverToBoxAdapter(
                          child: KeyedSubtree(
                            key: _discoveryKey,
                            child: const _DiscoveryHeader(),
                          ),
                        ),
                      if (!selecting)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SegmentHeaderDelegate(segment: segment),
                        ),
                      _segmentSliver(
                        segment: segment,
                        songsAsync: songsAsync,
                        mode: mode,
                        tree: songTree,
                        miniPlayerVisible: miniPlayerVisible,
                      ),
                    ],
                  ),
                  if (alphabet != null)
                    Positioned(
                      top: _SegmentHeaderDelegate._height + SpacingTokens.sm,
                      bottom: playerBarInset(context,
                              miniPlayerVisible: miniPlayerVisible) +
                          SpacingTokens.sm,
                      right: 0,
                      child: IgnorePointer(
                        // Hidden (and inert) until the rails scroll away, so it
                        // never floats over the discovery cards at the top.
                        ignoring: !tabsPinned,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: tabsPinned ? 1 : 0,
                          child: _AlphaScrubber(
                            alphabet: alphabet,
                            onJump: (index) => _jumpToItem(
                              segment: segment,
                              index: index,
                              viewportWidth: MediaQuery.sizeOf(context).width,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Back-to-top, beside the collapsed mini player.
                  Positioned(
                    right: SpacingTokens.lg,
                    bottom: safeBottom + 9,
                    child: IgnorePointer(
                      ignoring: !showToTop,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        scale: showToTop ? 1 : 0.6,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: showToTop ? 1 : 0,
                          child: _BackToTopButton(onTap: _scrollToTop),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

/// Pins the Songs/Albums/Artists/Genres tab row below the discovery rails. The
/// background matches the page so content scrolls invisibly under it, and a
/// hairline divider fades in only once content is actually tucked behind it.
class _SegmentHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SegmentHeaderDelegate({required this.segment});

  final LibrarySegment segment;

  /// 8 (top) + 34 (chip) + 10 (bottom) — matches [_SegmentRow]'s own padding.
  static const double _height = 52;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: overlapsContent
            ? Border(bottom: BorderSide(color: colors.divider, width: 0.5))
            : null,
      ),
      child: SizedBox(
        height: _height,
        child: _SegmentRow(selected: segment),
      ),
    );
  }

  @override
  bool shouldRebuild(_SegmentHeaderDelegate oldDelegate) =>
      oldDelegate.segment != segment;
}

/// The displayable A–Z index for a list: the full alphabet (plus a leading '#'
/// bucket when non-letter titles exist), the first item index each label jumps
/// to, and which labels actually have items (the rest render dimmed).
class _Alphabet {
  const _Alphabet(this.labels, this.target, this.present);

  /// Labels shown top→bottom, e.g. ['#','A','B',…,'Z'].
  final List<String> labels;

  /// Label → the item index its jump should land on. Absent letters resolve to
  /// the next present section below them (or the last one).
  final Map<String, int> target;

  /// Labels that have at least one item — shown at full strength.
  final Set<String> present;

  factory _Alphabet.fromKeys(List<String> keys) {
    final first = <String, int>{};
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i].trimLeft();
      final c = k.isEmpty ? '#' : k[0].toUpperCase();
      final code = c.codeUnitAt(0);
      final bucket = (code >= 65 && code <= 90) ? c : '#';
      first.putIfAbsent(bucket, () => i);
    }
    final present = first.keys.toSet();
    final labels = <String>[
      if (present.contains('#')) '#',
      for (var c = 65; c <= 90; c++) String.fromCharCode(c),
    ];
    final target = <String, int>{};
    // Fill each label with the nearest present section at or below it…
    int? next;
    for (var j = labels.length - 1; j >= 0; j--) {
      final lab = labels[j];
      if (first.containsKey(lab)) next = first[lab];
      if (next != null) target[lab] = next;
    }
    // …and any trailing labels past the last section fall back to the last one.
    int? prev;
    for (var j = 0; j < labels.length; j++) {
      final lab = labels[j];
      if (first.containsKey(lab)) prev = first[lab];
      target.putIfAbsent(lab, () => prev ?? 0);
    }
    return _Alphabet(labels, target, present);
  }

  /// Builds the index from a folded tree's `letter → first header row` map. The
  /// resulting [target] values are **row** indices (not song indices), which
  /// [_jumpToItem] resolves to a pixel offset for the Songs segment.
  factory _Alphabet.fromLetterRows(Map<String, int> firstRowByLetter) {
    final present = firstRowByLetter.keys.toSet();
    final labels = <String>[
      if (present.contains('#')) '#',
      for (var c = 65; c <= 90; c++) String.fromCharCode(c),
    ];
    final target = <String, int>{};
    int? next;
    for (var j = labels.length - 1; j >= 0; j--) {
      final lab = labels[j];
      if (firstRowByLetter.containsKey(lab)) next = firstRowByLetter[lab];
      if (next != null) target[lab] = next;
    }
    int? prev;
    for (var j = 0; j < labels.length; j++) {
      final lab = labels[j];
      if (firstRowByLetter.containsKey(lab)) prev = firstRowByLetter[lab];
      target.putIfAbsent(lab, () => prev ?? 0);
    }
    return _Alphabet(labels, target, present);
  }
}

/// The right-edge A–Z fast-scroll rail. Dragging a finger along it jumps the
/// list to that letter; letters near the finger swell in a fisheye "wave" (and
/// drift left toward the content) so the active region reads at a glance.
/// Reduce-motion keeps the type flat.
class _AlphaScrubber extends StatefulWidget {
  const _AlphaScrubber({required this.alphabet, required this.onJump});

  final _Alphabet alphabet;
  final void Function(int itemIndex) onJump;

  @override
  State<_AlphaScrubber> createState() => _AlphaScrubberState();
}

class _AlphaScrubberState extends State<_AlphaScrubber> {
  // The finger's local-Y while engaged; null when released (wave at rest).
  double? _dragY;
  int _activeIdx = -1;

  // How far the wave reaches and how strongly it magnifies.
  static const double _radius = 72;
  static const double _maxBoost = 0.95;

  void _engage(double localDy, double height) {
    final n = widget.alphabet.labels.length;
    if (n == 0) return;
    final slot = height / n;
    var idx = (localDy / slot).floor();
    if (idx < 0) idx = 0;
    if (idx >= n) idx = n - 1;
    setState(() => _dragY = localDy);
    if (idx != _activeIdx) {
      _activeIdx = idx;
      HapticFeedback.selectionClick();
      final t = widget.alphabet.target[widget.alphabet.labels[idx]];
      if (t != null) widget.onJump(t);
    }
  }

  void _release() {
    if (_dragY == null && _activeIdx == -1) return;
    setState(() {
      _dragY = null;
      _activeIdx = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final labels = widget.alphabet.labels;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final n = labels.length;
        final slot = n > 0 ? height / n : height;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _engage(d.localPosition.dy, height),
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          onVerticalDragStart: (d) => _engage(d.localPosition.dy, height),
          onVerticalDragUpdate: (d) => _engage(d.localPosition.dy, height),
          onVerticalDragEnd: (_) => _release(),
          onVerticalDragCancel: _release,
          child: SizedBox(
            width: 30,
            height: height,
            child: Stack(
              children: [
                for (var k = 0; k < n; k++)
                  _buildLabel(k, slot, colors, reduceMotion),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(
      int k, double slot, AppColors colors, bool reduceMotion) {
    final centerY = (k + 0.5) * slot;
    var scale = 1.0;
    var dx = 0.0;
    if (!reduceMotion && _dragY != null) {
      final dist = (centerY - _dragY!).abs();
      if (dist < _radius) {
        final t = 1 - dist / _radius; // 0…1, peaks at the finger
        final e = t * t; // ease so the crest is pronounced
        scale = 1 + _maxBoost * e;
        dx = -14 * e; // fisheye: swell toward the content
      }
    }
    final lab = widget.alphabet.labels[k];
    final present = widget.alphabet.present.contains(lab);
    final active = k == _activeIdx;
    final Color color = active
        ? colors.accent
        : present
            ? colors.onSurfaceMuted
            : colors.onSurfaceFaint.withOpacity(0.45);
    return Positioned(
      top: centerY - slot / 2,
      height: slot,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.centerRight,
            child: Text(
              lab,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small circular "back to top" affordance that sits beside the collapsed
/// mini player. Tapping it glides the page back to the very top.
class _BackToTopButton extends StatelessWidget {
  const _BackToTopButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.88,
      semanticLabel: 'Back to top',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: colors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(Icons.keyboard_arrow_up_rounded,
            color: colors.accent, size: 26),
      ),
    );
  }
}

class _SongsSliver extends ConsumerWidget {
  const _SongsSliver({
    required this.songsAsync,
    required this.mode,
    required this.tree,
    required this.miniPlayerVisible,
    required this.onPlay,
  });

  final AsyncValue<List<Song>> songsAsync;
  final DisplayMode mode;

  /// The folded hierarchy for list mode, or null when the sort doesn't fold.
  final SongTreeData? tree;
  final bool miniPlayerVisible;
  final void Function(List<Song> queue, int index) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bottom =
        playerBarInset(context, miniPlayerVisible: miniPlayerVisible);

    // Folded tree (Title/Album/Artist ascending, list mode): render the
    // hierarchy. A non-null tree already implies loaded, non-empty data.
    final tree = this.tree;
    if (mode == DisplayMode.list && tree != null) {
      return _buildTreeSliver(context, ref, tree, bottom);
    }

    SliverFillRemaining statusOf(AsyncValueLike<List<Song>> v) =>
        SliverFillRemaining(
          hasScrollBody: false,
          child: AsyncStateView<List<Song>>(
            value: v,
            data: (_) => const SizedBox.shrink(),
            isEmpty: (_) => true,
            emptyMessage: l10n.libraryEmpty,
            onRetry: () => ref.invalidate(songsProvider),
          ),
        );

    return songsAsync.like.map(
      loading: () => statusOf(AsyncValueLike<List<Song>>.loading()),
      error: (e) => statusOf(AsyncValueLike<List<Song>>.error(e)),
      data: (songs) {
        if (songs.isEmpty) {
          return statusOf(AsyncValueLike<List<Song>>.data(const []));
        }

        final selection = ref.watch(selectionProvider(LibraryPage._listId));
        final notifier =
            ref.read(selectionProvider(LibraryPage._listId).notifier);
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
            onPlay(songs, i);
          }
        }

        bool? selectedOf(Song s) =>
            selecting ? selection.contains(s.id) : null;

        switch (mode) {
          case DisplayMode.list:
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  SpacingTokens.md, 0, SpacingTokens.md, bottom),
              // Fixed extent → O(1) scrubber jumps on huge libraries.
              sliver: SliverFixedExtentList.builder(
                itemExtent: _kSongRowExtent,
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
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  SpacingTokens.sm, 0, SpacingTokens.sm, bottom),
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
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  SpacingTokens.lg, 0, SpacingTokens.lg, bottom),
              sliver: SliverGrid.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
      },
    );
  }

  /// Renders the folded hierarchy as one lazy [SliverList]. Every row is boxed
  /// to a fixed height (see `_treeRowExtent`) so it stays cheap to build and the
  /// scrubber's offset table stays exact. Tapping a track plays the tree's
  /// [SongTreeData.orderedSongs] from that point; selection mirrors the flat
  /// list, ranging over the same visual order.
  Widget _buildTreeSliver(
    BuildContext context,
    WidgetRef ref,
    SongTreeData tree,
    double bottom,
  ) {
    final rows = tree.rows;
    final ordered = tree.orderedSongs;
    final selection = ref.watch(selectionProvider(LibraryPage._listId));
    final notifier =
        ref.read(selectionProvider(LibraryPage._listId).notifier);
    final selecting = selection.active;
    final orderedIds = [for (final s in ordered) s.id];

    void onLongPressAt(int songIndex) {
      HapticFeedback.mediumImpact();
      final id = ordered[songIndex].id;
      if (selecting) {
        notifier.selectRange(orderedIds, id);
      } else {
        notifier.enter(id);
      }
    }

    void onTapAt(int songIndex) {
      if (selecting) {
        HapticFeedback.selectionClick();
        notifier.toggle(ordered[songIndex].id);
      } else {
        onPlay(ordered, songIndex);
      }
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
          SpacingTokens.sm, 0, SpacingTokens.sm, bottom),
      // Varied *but fixed-per-row* extents: the layout geometry is exact (like a
      // fixed-extent list), so the A–Z scrubber's `discovery + Σ extents` jump
      // lands precisely and never has to build the rows in between.
      sliver: SliverVariedExtentList.builder(
        itemCount: rows.length,
        itemExtentBuilder: (index, _) => _treeRowExtent(rows[index].kind),
        itemBuilder: (context, i) {
          final row = rows[i];
          switch (row.kind) {
            case LibRowKind.letter:
              return _LetterHeaderRow(label: row.label!);
            case LibRowKind.artist:
              final artist = row.artist!;
              return _ArtistHeaderRow(
                artist: artist,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArtistDetailPage(artist: artist),
                  ),
                ),
              );
            case LibRowKind.album:
              final album = row.album!;
              return _AlbumHeaderRow(
                album: album,
                depth: row.depth,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlbumDetailPage(album: album),
                  ),
                ),
                onPlay: () {
                  final q = [
                    for (final s in ordered)
                      if (s.albumId == album.id) s
                  ];
                  if (q.isNotEmpty) onPlay(q, 0);
                },
              );
            case LibRowKind.song:
              final song = row.song!;
              return _TreeSongRow(
                song: song,
                depth: row.depth,
                trackNumber: row.trackNumber,
                isLastInGroup: row.isLastInGroup,
                selected: selecting ? selection.contains(song.id) : null,
                onTap: () => onTapAt(row.songIndex),
                onLongPress: () => onLongPressAt(row.songIndex),
                onMore: () => showSongActions(context, song),
              );
          }
        },
      ),
    );
  }
}

/// Wraps a fixed-height tree row's content with a left gutter and one vertical
/// guide line per nesting level — the VS-Code "indent guide" look. Guides are
/// drawn as left borders on full-height cells so they read as continuous rails.
class _TreeRowFrame extends StatelessWidget {
  const _TreeRowFrame({
    required this.depth,
    required this.height,
    required this.child,
  });

  final int depth;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final guide = context.colors.divider;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: _kTreeGutter),
          for (var i = 0; i < depth; i++)
            Container(
              width: _kIndentStep,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: guide, width: 1.2)),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A big letter divider ("A") heading a title-sorted section, with a hairline
/// rule trailing off to the right.
class _LetterHeaderRow extends StatelessWidget {
  const _LetterHeaderRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _TreeRowFrame(
      depth: 0,
      height: _kLetterHeaderExtent,
      child: Padding(
        padding: const EdgeInsets.only(
            right: SpacingTokens.lg, top: SpacingTokens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextTheme.display.copyWith(
                color: colors.accent,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(child: Divider(color: colors.divider, height: 1)),
          ],
        ),
      ),
    );
  }
}

/// An artist section header (avatar · name · albums/songs count) that opens the
/// artist page. Top level of the by-artist tree.
class _ArtistHeaderRow extends StatelessWidget {
  const _ArtistHeaderRow({required this.artist, required this.onTap});
  final Artist artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: artist.name,
      child: _TreeRowFrame(
        depth: 0,
        height: _kArtistHeaderExtent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.sm, vertical: SpacingTokens.sm),
          child: Row(
            children: [
              ClipOval(
                child: AuraArtwork(
                  seed: artist.artworkSeed,
                  size: 46,
                  borderRadius: BorderRadius.circular(23),
                  hasArtwork: artist.hasArtwork,
                  artworkId: artist.firstSongId,
                ),
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
                      style: AppTextTheme.title.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${l10n.albumsCount(artist.albumCount)} · ${l10n.songsCount(artist.songCount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.caption
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: colors.onSurfaceFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// An album section header (cover · name · year) with a play button. Opens the
/// album page on tap. Sits at depth 0 (by-album tree) or depth 1 (nested under
/// an artist).
class _AlbumHeaderRow extends StatelessWidget {
  const _AlbumHeaderRow({
    required this.album,
    required this.depth,
    required this.onTap,
    required this.onPlay,
  });

  final Album album;
  final int depth;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final accent = SeedPalette.accent(album.artworkSeed);
    final subtitle = album.year?.toString() ?? l10n.songsCount(album.songCount);
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: album.name,
      child: _TreeRowFrame(
        depth: depth,
        height: _kAlbumHeaderExtent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.sm, vertical: SpacingTokens.sm),
          child: Row(
            children: [
              AuraArtwork(
                seed: album.artworkSeed,
                size: 44,
                borderRadius: RadiusTokens.brSm,
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
                      style: AppTextTheme.title.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.caption
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.play,
                onPressed: onPlay,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.play_circle_fill, size: 30, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A track row inside the tree. In the title tree it shows a thumbnail + artist;
/// in the album/artist trees it shows a track number (or a now-playing
/// indicator) and no thumbnail, since the album header already carries the art.
/// A hairline under each track (dropped on the last of a group) separates rows.
class _TreeSongRow extends ConsumerWidget {
  const _TreeSongRow({
    required this.song,
    required this.depth,
    required this.trackNumber,
    required this.isLastInGroup,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  final Song song;
  final int depth;
  final int? trackNumber;
  final bool isLastInGroup;
  final bool? selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selecting = selected != null;
    final isSelected = selected ?? false;
    final isCurrent = !selecting &&
        ref.watch(currentSongProvider.select((s) => s?.id == song.id));
    final playing = isCurrent &&
        ref.watch(playbackStateProvider
            .select((st) => st.valueOrNull?.playing ?? false));
    final accent = SeedPalette.accent(song.artworkSeed);
    final highlight = isSelected || isCurrent;

    // Leading slot: a check in selection mode, otherwise the now-playing bars,
    // the track number (album/artist trees) or a thumbnail (title tree).
    final Widget leading;
    if (selecting) {
      leading = SizedBox(
        width: 40,
        child: Center(child: _TreeSelectCheck(selected: isSelected)),
      );
    } else if (trackNumber != null) {
      leading = SizedBox(
        width: 34,
        child: Center(
          child: isCurrent
              ? NowPlayingIndicator(color: accent, animating: playing)
              : Text(
                  '$trackNumber',
                  style: AppTextTheme.body.copyWith(
                    color: colors.onSurfaceFaint,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      );
    } else {
      leading = AuraArtwork(
        seed: song.artworkSeed,
        size: 40,
        hasArtwork: song.hasArtwork,
        artworkId: int.tryParse(song.id),
      );
    }

    return PressScale(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.98,
      semanticLabel: '${song.title}, ${song.artist}',
      child: _TreeRowFrame(
        depth: depth,
        height: _kTreeSongExtent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highlight ? accent.withOpacity(0.07) : Colors.transparent,
            border: isLastInGroup
                ? null
                : Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: SpacingTokens.xs),
            child: Row(
              children: [
                leading,
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.body.copyWith(
                          color: isCurrent ? accent : colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (trackNumber == null) ...[
                        const SizedBox(height: 1),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextTheme.caption
                              .copyWith(color: colors.onSurfaceMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  song.duration.clock,
                  style: AppTextTheme.caption
                      .copyWith(color: colors.onSurfaceFaint),
                ),
                if (!selecting)
                  IconButton(
                    onPressed: onMore,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.more_vert,
                        size: 20, color: colors.onSurfaceFaint),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The leading check circle shown on a tree track row in selection mode.
class _TreeSelectCheck extends StatelessWidget {
  const _TreeSelectCheck({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.accent : Colors.transparent,
        border: Border.all(
          color: selected ? colors.accent : colors.onSurfaceFaint,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 14, color: colors.background)
          : null,
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
        decoration: _discoveryCardDecoration(colors),
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

/// Albums grid — rendered as a sliver so it tucks under the pinned tabs.
class _AlbumsSliver extends ConsumerWidget {
  const _AlbumsSliver({required this.miniPlayerVisible});

  final bool miniPlayerVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final albumsAsync = ref.watch(albumsProvider);
    final bottom =
        playerBarInset(context, miniPlayerVisible: miniPlayerVisible);

    SliverFillRemaining statusOf(AsyncValueLike<List<Album>> v) =>
        SliverFillRemaining(
          hasScrollBody: false,
          child: AsyncStateView<List<Album>>(
            value: v,
            data: (_) => const SizedBox.shrink(),
            isEmpty: (_) => true,
            emptyMessage: l10n.libraryEmpty,
            emptyIcon: Icons.album_outlined,
            onRetry: () => ref.invalidate(songsProvider),
          ),
        );

    return albumsAsync.like.map(
      loading: () => statusOf(AsyncValueLike<List<Album>>.loading()),
      error: (e) => statusOf(AsyncValueLike<List<Album>>.error(e)),
      data: (albums) => albums.isEmpty
          ? statusOf(AsyncValueLike<List<Album>>.data(const []))
          : SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, bottom),
              sliver: SliverGrid.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
            ),
    );
  }
}

/// Artists list — rendered as a sliver so it tucks under the pinned tabs.
class _ArtistsSliver extends ConsumerWidget {
  const _ArtistsSliver({required this.miniPlayerVisible});

  final bool miniPlayerVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final artistsAsync = ref.watch(artistsProvider);
    final bottom =
        playerBarInset(context, miniPlayerVisible: miniPlayerVisible);

    SliverFillRemaining statusOf(AsyncValueLike<List<Artist>> v) =>
        SliverFillRemaining(
          hasScrollBody: false,
          child: AsyncStateView<List<Artist>>(
            value: v,
            data: (_) => const SizedBox.shrink(),
            isEmpty: (_) => true,
            emptyMessage: l10n.libraryEmpty,
            emptyIcon: Icons.person_outline,
            onRetry: () => ref.invalidate(songsProvider),
          ),
        );

    return artistsAsync.like.map(
      loading: () => statusOf(AsyncValueLike<List<Artist>>.loading()),
      error: (e) => statusOf(AsyncValueLike<List<Artist>>.error(e)),
      data: (artists) => artists.isEmpty
          ? statusOf(AsyncValueLike<List<Artist>>.data(const []))
          : SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  SpacingTokens.md, 0, SpacingTokens.md, bottom),
              sliver: SliverFixedExtentList.builder(
                itemExtent: _kArtistRowExtent,
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
            ),
    );
  }
}

/// Genres list — rendered as a sliver so it tucks under the pinned tabs.
class _GenresSliver extends ConsumerWidget {
  const _GenresSliver({required this.miniPlayerVisible});

  final bool miniPlayerVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final genresAsync = ref.watch(genresProvider);
    final bottom =
        playerBarInset(context, miniPlayerVisible: miniPlayerVisible);

    SliverFillRemaining statusOf(AsyncValueLike<List<Genre>> v) =>
        SliverFillRemaining(
          hasScrollBody: false,
          child: AsyncStateView<List<Genre>>(
            value: v,
            data: (_) => const SizedBox.shrink(),
            isEmpty: (_) => true,
            emptyMessage: l10n.libraryEmpty,
            emptyIcon: Icons.category_outlined,
            onRetry: () => ref.invalidate(songsProvider),
          ),
        );

    return genresAsync.like.map(
      loading: () => statusOf(AsyncValueLike<List<Genre>>.loading()),
      error: (e) => statusOf(AsyncValueLike<List<Genre>>.error(e)),
      data: (genres) => genres.isEmpty
          ? statusOf(AsyncValueLike<List<Genre>>.data(const []))
          : SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  SpacingTokens.md, 0, SpacingTokens.md, bottom),
              sliver: SliverList.builder(
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
    // Drop anything already surfaced elsewhere so the home never shows the same
    // mix twice: pinned collections have their own rail above, and a collection
    // promoted into the Top Picks grid (e.g. the contextual "Chill" mood)
    // shouldn't reappear here.
    final pinned = ref.watch(pinnedCollectionsProvider);
    final pickIds = {for (final p in ref.watch(topPicksProvider)) p.id};
    final collections = [
      for (final c in all)
        if (!pinned.contains(c.id) && !pickIds.contains(c.id)) c,
    ];
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
        decoration: _discoveryCardDecoration(colors),
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
              final plSongs = [
                for (final id in p.songIds)
                  if (byId.containsKey(id)) byId[id]!,
              ];
              return PressScale(
                onTap: () => openUserPlaylist(context, p.id),
                pressedScale: 0.97,
                semanticLabel: p.name,
                child: CollectionCover.label(
                  title: p.name,
                  count: p.songIds.length,
                  icon: Icons.queue_music_rounded,
                  colorSeed: p.id,
                  songs: plSongs,
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

    final tiles = <(AutoPlaylist, String, IconData, int, List<Song>)>[];
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
      tiles.add((type, label, icon, songs.length, songs));
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
              final (type, label, icon, count, plSongs) = tiles[i];
              return PressScale(
                onTap: () => openAutoPlaylist(context, type),
                pressedScale: 0.97,
                semanticLabel: label,
                child: CollectionCover.label(
                  title: label,
                  count: count,
                  icon: icon,
                  colorSeed: 'auto_${type.name}',
                  songs: plSongs,
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
    // Don't re-suggest artists that already appear in the Top Artists shelf.
    final topIds = {for (final a in ref.watch(topArtistsProvider)) a.id};
    final artists = [
      for (final a in ref.watch(suggestedArtistsProvider))
        if (!topIds.contains(a.id)) a,
    ];
    if (artists.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, SpacingTokens.md, SpacingTokens.lg, 0),
      child: Container(
        decoration: _discoveryCardDecoration(colors),
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
