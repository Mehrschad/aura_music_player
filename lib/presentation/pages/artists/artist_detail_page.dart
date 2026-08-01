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
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/song.dart';
import '../../providers/artist_bio_providers.dart';
import '../../providers/artist_favorites_providers.dart';
import '../../providers/cover_palette_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/now_playing_indicator.dart';
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
    final palette = ref.watch(coverPaletteProvider((
      seed: artist.artworkSeed,
      hasArtwork: artist.hasArtwork,
      artworkId: artist.firstSongId,
    ))).valueOrNull;
    final accent = palette?.accent ?? SeedPalette.accent(artist.artworkSeed);
    final wash = palette?.wash ?? SeedPalette.wash(artist.artworkSeed);
    final isFav = ref.watch(isArtistFavoriteProvider(artist.id));

    // The artwork colour is carried into the top of the scroll area (so the
    // content feels connected to the art), fading to pure black lower down.
    // A stronger wash than before makes the page feel alive rather than a flat
    // black sheet.
    final pageBackground =
        Color.alphaBlend(wash.withOpacity(0.38), colors.background);

    // Half-screen hero: the artwork fills the top 50 % of the display.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = screenHeight * 0.50;

    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.42, 0.9],
            colors: [pageBackground, pageBackground, colors.background],
          ),
        ),
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            // Start transparent so the hero photo shows through the status bar.
            systemOverlayStyle: SystemUiOverlayStyle.light,
            expandedHeight: heroHeight,
            pinned: true,
            // Collapsed app bar uses the wash-tinted background colour.
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            actions: [
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
                  color: isFav ? colors.favorite : Colors.white,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (v) {
                  final songs = songsAsync.valueOrNull ?? const <Song>[];
                  if (songs.isEmpty) return;
                  final ctrl = ref.read(audioControllerProvider);
                  if (v == 'next') {
                    for (final s in songs.reversed) {
                      ctrl.playNext(s);
                    }
                  } else {
                    for (final s in songs) {
                      ctrl.addToQueue(s);
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.addedToQueue),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'next',
                    child: Row(
                      children: [
                        const Icon(Icons.queue_play_next, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.playNext),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'queue',
                    child: Row(
                      children: [
                        const Icon(Icons.add_to_queue, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.addToQueue),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                // As the bar collapses, slide the title's start padding out to
                // clear the back button — a fixed start padding let the name
                // slide under the arrow.
                final settings = context.dependOnInheritedWidgetOfExactType<
                    FlexibleSpaceBarSettings>();
                var t = 0.0;
                if (settings != null) {
                  final delta = settings.maxExtent - settings.minExtent;
                  if (delta > 0) {
                    t = (1 -
                            (settings.currentExtent - settings.minExtent) /
                                delta)
                        .clamp(0.0, 1.0);
                  }
                }
                final startPad =
                    SpacingTokens.xl + (56 - SpacingTokens.xl) * t;
                return FlexibleSpaceBar(
                  titlePadding: EdgeInsetsDirectional.fromSTEB(
                      startPad, 0, SpacingTokens.xl, SpacingTokens.lg),
                  title: Text(
                    artist.name,
                style: AppTextTheme.display.copyWith(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 12,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // collapseMode: none so the image stays visible while collapsing;
              // it parallax-shrinks naturally with the default behaviour.
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Full-bleed artist photo — no ClipRect rounding.
                  AuraArtwork(
                    seed: artist.artworkSeed,
                    size: double.maxFinite,
                    borderRadius: BorderRadius.zero,
                    hasArtwork: artist.hasArtwork,
                    artworkId: artist.firstSongId,
                  ),
                  // Subtle palette hue wash over the photo.
                  DecoratedBox(
                    decoration:
                        BoxDecoration(color: accent.withOpacity(0.10)),
                  ),
                  // Top scrim: dark vignette so back button / status bar remain
                  // legible.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withOpacity(0.42),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Bottom melt: image fades into pageBackground so the scroll
                  // content appears to grow out of the photo — the iOS 27
                  // "liquid" transition.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.55, 1.0],
                        colors: [
                          Colors.transparent,
                          pageBackground.withOpacity(0.60),
                          pageBackground,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
                );
              },
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.albumsCount(artist.albumCount)} · ${l10n.songsCount(artist.songCount)}',
                    style: AppTextTheme.body
                        .copyWith(color: colors.onSurfaceMuted),
                  ),
                  songsAsync.maybeWhen(
                    data: (songs) {
                      final genres = _topGenres(songs);
                      if (genres.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: SpacingTokens.sm),
                        child: Wrap(
                          spacing: SpacingTokens.sm,
                          runSpacing: SpacingTokens.xs,
                          children: [
                            for (final g in genres)
                              _GenreChip(label: g, accent: accent),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  songsAsync.maybeWhen(
                    data: (songs) => songs.isEmpty
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              Expanded(
                                child: _PillButton(
                                  icon: Icons.play_arrow,
                                  label: l10n.play,
                                  filled: true,
                                  accent: accent,
                                  pageBackground: pageBackground,
                                  onTap: () => ref
                                      .read(audioControllerProvider)
                                      .playQueue(songs),
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.sm),
                              Expanded(
                                child: _PillButton(
                                  icon: Icons.shuffle,
                                  label: l10n.shuffle,
                                  filled: false,
                                  accent: accent,
                                  pageBackground: pageBackground,
                                  onTap: () {
                                    final ctrl =
                                        ref.read(audioControllerProvider);
                                    ctrl.setShuffle(true);
                                    ctrl.playQueue(songs);
                                  },
                                ),
                              ),
                            ],
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // ── Biography (downloaded from Wikipedia, cached offline) ────────
          SliverToBoxAdapter(child: _ArtistBio(artistName: artist.name)),

          // ── Popular — the artist's most-played tracks ───────────────────
          songsAsync.maybeWhen(
            data: (songs) {
              final popular = _popularTracks(songs);
              if (popular.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: _PopularSection(songs: popular, accent: accent),
              );
            },
            orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Tracks, grouped album-by-album ──────────────────────────────
          // Each album is a titled section (cover · name · year) followed by
          // its tracks, numbered from 1. Newest albums come first.
          songsAsync.when(
            loading: () => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xxl),
                child: Center(
                  child: SizedBox(
                    width: SpacingTokens.xxl,
                    height: SpacingTokens.xxl,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.onSurfaceFaint),
                  ),
                ),
              ),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.xl),
                child: Text(l10n.errorGeneric,
                    style: AppTextTheme.body
                        .copyWith(color: colors.onSurfaceMuted)),
              ),
            ),
            data: (songs) {
              if (songs.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              final groups =
                  _groupByAlbum(songs, albumsAsync.valueOrNull ?? const []);
              final rows = _buildRows(groups);
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final row = rows[i];
                    if (row.group != null) {
                      return _AlbumSectionHeader(
                        group: row.group!,
                        accent: accent,
                        onTap: row.group!.album == null
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AlbumDetailPage(
                                        album: row.group!.album!),
                                  ),
                                ),
                        onPlay: () => ref
                            .read(audioControllerProvider)
                            .playQueue(row.group!.songs),
                      );
                    }
                    final group = row.trackGroup!;
                    return _AlbumTrackTile(
                      song: group.songs[row.trackIndex],
                      trackNumber: row.trackIndex + 1,
                      isLast: row.trackIndex == group.songs.length - 1,
                      accent: accent,
                      onTap: () => ref
                          .read(audioControllerProvider)
                          .playQueue(group.songs, startIndex: row.trackIndex),
                      onMore: () => showSongActions(
                          context, group.songs[row.trackIndex]),
                    );
                  },
                  childCount: rows.length,
                ),
              );
            },
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: playerBarInset(context,
                  miniPlayerVisible: miniPlayerVisible),
            ),
          ),
          ],
        ),
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

/// A single album's worth of the artist's tracks, kept together so the detail
/// page can render one titled section per album. [album] carries the cover /
/// year metadata; it is null only for the rare "no album tag" bucket.
class _AlbumGroup {
  const _AlbumGroup({required this.album, required this.name, required this.songs});
  final Album? album;
  final String name;
  final List<Song> songs;

  int? get year => album?.year;
  bool get hasArtwork => album?.hasArtwork ?? songs.first.hasArtwork;
  int? get artworkId => album?.firstSongId ?? int.tryParse(songs.first.id);
  String get artworkSeed => album?.artworkSeed ?? songs.first.artworkSeed;
}

/// Buckets [songs] by album, ordering the albums newest-year-first (untagged
/// years last, then A–Z) and each album's tracks by disc + track number — so a
/// tap on any track plays that album in its natural running order.
List<_AlbumGroup> _groupByAlbum(List<Song> songs, List<Album> albums) {
  final albumById = {for (final a in albums) a.id: a};
  final byId = <String, List<Song>>{};
  final order = <String>[];
  for (final s in songs) {
    final list = byId.putIfAbsent(s.albumId, () {
      order.add(s.albumId);
      return <Song>[];
    });
    list.add(s);
  }

  final groups = [
    for (final id in order)
      _AlbumGroup(
        album: albumById[id],
        name: byId[id]!.first.album,
        songs: byId[id]!
          ..sort((a, b) {
            final discCmp = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
            if (discCmp != 0) return discCmp;
            return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
          }),
      ),
  ]..sort((a, b) {
      final ay = a.year, by = b.year;
      if (ay != null && by != null && ay != by) return by.compareTo(ay);
      if (ay == null && by != null) return 1;
      if (ay != null && by == null) return -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return groups;
}

/// Flattens album groups into a single row stream: a header row followed by
/// one row per track, so the whole track list scrolls as one lazy SliverList.
List<_Row> _buildRows(List<_AlbumGroup> groups) {
  final rows = <_Row>[];
  for (final group in groups) {
    rows.add(_Row.header(group));
    for (var i = 0; i < group.songs.length; i++) {
      rows.add(_Row.track(group, i));
    }
  }
  return rows;
}

class _Row {
  const _Row.header(_AlbumGroup this.group)
      : trackGroup = null,
        trackIndex = -1;
  const _Row.track(_AlbumGroup this.trackGroup, this.trackIndex)
      : group = null;

  /// Non-null when this row is an album section header.
  final _AlbumGroup? group;

  /// Non-null when this row is a track; [trackIndex] indexes into its songs.
  final _AlbumGroup? trackGroup;
  final int trackIndex;
}

/// The artist's up-to-five most-played tracks, most first. Empty when there's
/// no play history yet, so the "Popular" section simply doesn't appear.
List<Song> _popularTracks(List<Song> songs) {
  final withPlays = [for (final s in songs) if (s.playCount > 0) s]
    ..sort((a, b) => b.playCount.compareTo(a.playCount));
  return withPlays.take(5).toList();
}

/// The artist's most common genre tags (up to three), busiest first.
List<String> _topGenres(List<Song> songs) {
  final counts = <String, int>{};
  for (final s in songs) {
    final g = (s.genre ?? '').trim();
    if (g.isEmpty) continue;
    counts[g] = (counts[g] ?? 0) + 1;
  }
  final sorted = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return sorted.take(3).toList();
}

/// A small accent-tinted genre pill shown under the artist name.
class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: RadiusTokens.brPill,
        border: Border.all(color: accent.withOpacity(0.32)),
      ),
      child: Text(
        label,
        style: AppTextTheme.caption
            .copyWith(color: accent, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The "Popular" section: the artist's most-played tracks in the standard
/// library row so it feels native. Tapping plays the list from that track.
class _PopularSection extends ConsumerWidget {
  const _PopularSection({required this.songs, required this.accent});
  final List<Song> songs;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.xl,
            SpacingTokens.md,
            SpacingTokens.xl,
            SpacingTokens.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 15,
                margin: const EdgeInsets.only(right: SpacingTokens.sm),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'POPULAR',
                style: AppTextTheme.caption.copyWith(
                  color: colors.onSurfaceFaint,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < songs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
            child: SongListTile(
              song: songs[i],
              onTap: () => ref
                  .read(audioControllerProvider)
                  .playQueue(songs, startIndex: i),
              onMore: () => showSongActions(context, songs[i]),
            ),
          ),
      ],
    );
  }
}

/// Album section header: cover · name · year, with a small round play button.
/// Tapping the row opens the full album page.
class _AlbumSectionHeader extends StatelessWidget {
  const _AlbumSectionHeader({
    required this.group,
    required this.accent,
    required this.onTap,
    required this.onPlay,
  });

  final _AlbumGroup group;
  final Color accent;
  final VoidCallback? onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final subtitle = group.year?.toString() ?? l10n.songsCount(group.songs.length);

    return PressScale(
      onTap: onTap ?? () {},
      pressedScale: 0.98,
      semanticLabel: group.name,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.xl,
          SpacingTokens.md,
          SpacingTokens.md,
          SpacingTokens.xs,
        ),
        child: Row(
          children: [
            AuraArtwork(
              seed: group.artworkSeed,
              size: 64,
              borderRadius: RadiusTokens.brMd,
              hasArtwork: group.hasArtwork,
              artworkId: group.artworkId,
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.title.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
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
              icon: Icon(Icons.play_circle_fill, size: 34, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// A numbered track row inside an album section: index · title · duration ·
/// overflow menu, with a hairline divider between tracks. Highlights and shows
/// a dancing-bars indicator when it is the track currently playing.
class _AlbumTrackTile extends ConsumerWidget {
  const _AlbumTrackTile({
    required this.song,
    required this.trackNumber,
    required this.isLast,
    required this.accent,
    required this.onTap,
    required this.onMore,
  });

  final Song song;
  final int trackNumber;
  final bool isLast;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isCurrent =
        ref.watch(currentSongProvider.select((s) => s?.id == song.id));
    final playing = isCurrent &&
        ref.watch(playbackStateProvider
            .select((st) => st.valueOrNull?.playing ?? false));

    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: '${song.title}, ${song.artist}',
      child: Container(
        color: isCurrent ? accent.withOpacity(0.07) : Colors.transparent,
        padding: const EdgeInsets.only(left: SpacingTokens.xl),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: isCurrent
                  ? NowPlayingIndicator(color: accent, animating: playing)
                  : Text(
                      '$trackNumber',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.body.copyWith(
                        color: colors.onSurfaceFaint,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SpacingTokens.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.title.copyWith(
                        color: isCurrent ? accent : colors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(top: SpacingTokens.md),
                        child: Divider(
                            height: 1, thickness: 1, color: colors.divider),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              song.duration.clock,
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
            ),
            IconButton(
              onPressed: onMore,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.more_vert, size: 20, color: colors.onSurfaceFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill action button — accent-fill for Play, glass-surface outline for
/// Shuffle. Uses PressScale so there is no Material ink ripple.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.accent,
    required this.onTap,
    this.pageBackground,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback onTap;
  /// The wash-tinted page background, used as the outline-button fill.
  final Color? pageBackground;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = filled ? Colors.white : colors.onSurface;
    final outlineFill = pageBackground != null
        ? Color.alphaBlend(colors.onSurface.withOpacity(0.06), pageBackground!)
        : colors.surfaceElevated;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? accent : outlineFill,
          borderRadius: RadiusTokens.brPill,
          border: filled ? null : Border.all(color: colors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: SpacingTokens.sm),
            Text(label, style: AppTextTheme.action.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
