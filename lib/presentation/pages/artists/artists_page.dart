import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/artist.dart';
import '../../providers/artist_favorites_providers.dart';
import '../../providers/async_value_x.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/library/artist_grid_tile.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/section_header.dart';
import 'artist_detail_page.dart';

/// The artists tab: a photo-forward grid of circular avatars, a horizontal rail
/// of favourited artists pinned at the top, and an A–Z fast-scroll index down
/// the right edge for large libraries.
class ArtistsPage extends ConsumerStatefulWidget {
  const ArtistsPage({super.key});

  @override
  ConsumerState<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends ConsumerState<ArtistsPage> {
  static const int _crossAxisCount = 2;
  static const double _mainAxisSpacing = SpacingTokens.xl;
  static const double _crossAxisSpacing = SpacingTokens.lg;
  static const double _gridTopPad = SpacingTokens.sm;

  final ScrollController _scrollController = ScrollController();

  // The favourites rail is measured after layout so the A–Z index can jump to
  // the right grid offset (the rail scrolls away above the grid).
  final GlobalKey _railKey = GlobalKey();

  // Grid row pitch (tile extent + spacing), recomputed in [build] from the
  // available width. Used by the A–Z index to convert an item index → offset.
  double _rowExtent = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// First alphabetical bucket for an artist name: an uppercase A–Z letter, or
  /// '#' for anything that doesn't start with a Latin letter.
  String _bucketOf(String name) {
    final trimmed = name.trimLeft();
    if (trimmed.isEmpty) return '#';
    final c = trimmed[0].toUpperCase();
    return (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0) ? c : '#';
  }

  void _jumpToIndex(int index) {
    if (!_scrollController.hasClients || _rowExtent <= 0) return;
    final railBox = _railKey.currentContext?.findRenderObject() as RenderBox?;
    final railHeight = railBox?.size.height ?? 0;
    final gridTop = railHeight + _gridTopPad;
    final row = index ~/ _crossAxisCount;
    final target = (gridTop + row * _rowExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final artistsAsync = ref.watch(artistsProvider);
    final count =
        artistsAsync.maybeWhen(data: (a) => a.length, orElse: () => 0);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l10n.tabArtists,
            subtitle: count > 0 ? l10n.artistsCount(count) : null,
          ),
          Expanded(
            child: AsyncStateView<List<Artist>>(
              value: artistsAsync.like,
              isEmpty: (a) => a.isEmpty,
              emptyMessage: l10n.libraryEmpty,
              emptyIcon: Icons.person_outline,
              onRetry: () => ref.invalidate(songsProvider),
              data: (artists) => _ArtistsGrid(
                artists: artists,
                scrollController: _scrollController,
                railKey: _railKey,
                bucketOf: _bucketOf,
                onJumpToIndex: _jumpToIndex,
                onRowExtentComputed: (v) => _rowExtent = v,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistsGrid extends ConsumerWidget {
  const _ArtistsGrid({
    required this.artists,
    required this.scrollController,
    required this.railKey,
    required this.bucketOf,
    required this.onJumpToIndex,
    required this.onRowExtentComputed,
  });

  final List<Artist> artists;
  final ScrollController scrollController;
  final GlobalKey railKey;
  final String Function(String name) bucketOf;
  final void Function(int index) onJumpToIndex;
  final ValueChanged<double> onRowExtentComputed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favIds = ref.watch(artistFavoritesProvider);
    final miniPlayerVisible = ref.watch(hasMediaProvider);

    // Favourited artists, in the same A–Z order as the grid.
    final favorites =
        artists.where((a) => favIds.contains(a.id)).toList(growable: false);

    // Ordered list of section buckets (as they first appear) + the index of the
    // first artist in each, so the A–Z bar can jump straight to it.
    final letterOrder = <String>[];
    final letterFirstIndex = <String, int>{};
    for (var i = 0; i < artists.length; i++) {
      final b = bucketOf(artists[i].name);
      if (!letterFirstIndex.containsKey(b)) {
        letterFirstIndex[b] = i;
        letterOrder.add(b);
      }
    }
    final showIndexBar = letterOrder.length > 1;

    String subtitleFor(Artist a) =>
        '${l10n.albumsCount(a.albumCount)} · ${l10n.songsCount(a.songCount)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        const cross = _ArtistsPageState._crossAxisCount;
        const edge = SpacingTokens.lg;
        final indexBarWidth = showIndexBar ? 22.0 : 0.0;

        final avail = constraints.maxWidth -
            edge * 2 -
            indexBarWidth -
            _ArtistsPageState._crossAxisSpacing * (cross - 1);
        final cellWidth = avail / cross;
        // Matches the caption block reserved inside ArtistGridTile.
        final mainAxisExtent = cellWidth + 48;
        onRowExtentComputed(
            mainAxisExtent + _ArtistsPageState._mainAxisSpacing);

        final bottomInset = playerBarInset(context,
            miniPlayerVisible: miniPlayerVisible);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            CustomScrollView(
              controller: scrollController,
              slivers: [
                if (favorites.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _FavoritesRail(
                      key: railKey,
                      favorites: favorites,
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: edge,
                    right: edge + indexBarWidth,
                    top: _ArtistsPageState._gridTopPad,
                    bottom: bottomInset,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: _ArtistsPageState._mainAxisSpacing,
                      crossAxisSpacing: _ArtistsPageState._crossAxisSpacing,
                      mainAxisExtent: mainAxisExtent,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final a = artists[i];
                        return ArtistGridTile(
                          artist: a,
                          subtitle: subtitleFor(a),
                          isFavorite: favIds.contains(a.id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ArtistDetailPage(artist: a),
                            ),
                          ),
                        );
                      },
                      childCount: artists.length,
                    ),
                  ),
                ),
              ],
            ),
            if (showIndexBar)
              Positioned(
                top: 0,
                bottom: bottomInset,
                right: 0,
                width: indexBarWidth + edge,
                child: _AlphabetIndexBar(
                  letters: letterOrder,
                  onSelected: (letter) {
                    final idx = letterFirstIndex[letter];
                    if (idx != null) onJumpToIndex(idx);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Horizontal rail of favourited artists, pinned above the grid.
class _FavoritesRail extends StatelessWidget {
  const _FavoritesRail({
    super.key,
    required this.favorites,
  });

  final List<Artist> favorites;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    const avatar = 68.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.xl,
            SpacingTokens.xs,
            SpacingTokens.xl,
            SpacingTokens.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.favorite, size: 13, color: colors.favorite),
              const SizedBox(width: SpacingTokens.xs),
              Text(
                l10n.autoFavorites.toUpperCase(),
                style: AppTextTheme.caption.copyWith(
                  color: colors.onSurfaceFaint,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: avatar + SpacingTokens.sm + 16,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
            itemCount: favorites.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: SpacingTokens.md),
            itemBuilder: (context, i) {
              final a = favorites[i];
              return PressScale(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArtistDetailPage(artist: a),
                  ),
                ),
                semanticLabel: a.name,
                child: SizedBox(
                  width: avatar + 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.scrim.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: AuraArtwork(
                          seed: a.artworkSeed,
                          size: avatar,
                          borderRadius: RadiusTokens.brPill,
                          hasArtwork: a.hasArtwork,
                          artworkId: a.firstSongId,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.xs),
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextTheme.caption
                            .copyWith(color: colors.onSurface),
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

/// The A–Z fast-scroll index down the right edge. Dragging or tapping a letter
/// reports it via [onSelected]; a floating bubble echoes the active letter.
class _AlphabetIndexBar extends StatefulWidget {
  const _AlphabetIndexBar({required this.letters, required this.onSelected});

  final List<String> letters;
  final ValueChanged<String> onSelected;

  @override
  State<_AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<_AlphabetIndexBar> {
  int? _activeIndex;

  void _handle(double dy, double height) {
    if (widget.letters.isEmpty || height <= 0) return;
    final seg = height / widget.letters.length;
    final idx = (dy ~/ seg).clamp(0, widget.letters.length - 1);
    if (idx != _activeIndex) {
      setState(() => _activeIndex = idx);
      HapticFeedback.selectionClick();
      widget.onSelected(widget.letters[idx]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) =>
              _handle(d.localPosition.dy, height),
          onVerticalDragUpdate: (d) =>
              _handle(d.localPosition.dy, height),
          onVerticalDragEnd: (_) => setState(() => _activeIndex = null),
          onVerticalDragCancel: () => setState(() => _activeIndex = null),
          onTapDown: (d) => _handle(d.localPosition.dy, height),
          onTapUp: (_) => setState(() => _activeIndex = null),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: SpacingTokens.xs),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.letters.length; i++)
                        Text(
                          widget.letters[i],
                          style: AppTextTheme.caption2.copyWith(
                            color: _activeIndex == i
                                ? colors.accent
                                : colors.onSurfaceFaint,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_activeIndex != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: SpacingTokens.xxxl),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.scrim.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.letters[_activeIndex!],
                      style: AppTextTheme.title2.copyWith(
                        color: colors.onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
