import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/song.dart';
import '../../providers/cover_palette_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/now_playing_indicator.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/press_scale.dart';
import '../tag_editor/tag_editor_page.dart';

class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({super.key, required this.album});
  final Album album;

  /// Start the album as a fresh queue, optionally shuffled, from [startIndex].
  void _play(WidgetRef ref, List<Song> songs,
      {bool shuffle = false, int startIndex = 0}) {
    if (songs.isEmpty) return;
    final ctrl = ref.read(audioControllerProvider);
    ctrl.setShuffle(shuffle);
    ctrl.playQueue(songs, startIndex: startIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(albumSongsProvider(album.id));
    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final palette = ref.watch(coverPaletteProvider((
      seed: album.artworkSeed,
      hasArtwork: album.hasArtwork,
      artworkId: album.firstSongId,
    ))).valueOrNull;
    final accent = palette?.accent ?? SeedPalette.accent(album.artworkSeed);
    final wash = palette?.wash ?? SeedPalette.wash(album.artworkSeed);
    // A stronger wash carried into the top of the scroll area, fading to pure
    // black lower down, so the page picks up the cover's colour instead of
    // dropping to a flat black sheet under the hero.
    final pageBackground =
        Color.alphaBlend(wash.withOpacity(0.38), colors.background);

    final heroHeight = MediaQuery.sizeOf(context).height * 0.44;

    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 0.85],
            colors: [pageBackground, pageBackground, colors.background],
          ),
        ),
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            expandedHeight: heroHeight,
            pinned: true,
            // Soft dark circle behind the back arrow so it reads on artwork.
            leading: Padding(
              padding: const EdgeInsets.all(SpacingTokens.sm),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
            actions: [
              // Edit the album's tags / artwork — applies to all its tracks.
              songsAsync.maybeWhen(
                data: (songs) => songs.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: l10n.editAlbum,
                        onPressed: () => openTagEditor(context, songs),
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.white),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _Hero(
                album: album,
                background: pageBackground,
                accent: accent,
                meta: songsAsync.maybeWhen(
                  data: (songs) => _metaLine(l10n, songs),
                  orElse: () => null,
                ),
              ),
            ),
          ),

          // Action row: Play (accent fill) + Shuffle (surface outline).
          SliverToBoxAdapter(
            child: songsAsync.maybeWhen(
              data: (songs) => songs.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SpacingTokens.xl,
                        SpacingTokens.xs,
                        SpacingTokens.xl,
                        SpacingTokens.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.play_arrow,
                              label: l10n.play,
                              filled: true,
                              accent: accent,
                              onTap: () => _play(ref, songs),
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.sm),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.shuffle,
                              label: l10n.shuffle,
                              filled: false,
                              accent: accent,
                              onTap: () => _play(ref, songs, shuffle: true),
                            ),
                          ),
                        ],
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // Song list — split into disc sections when the album spans
          // multiple discs.
          songsAsync.when(
            loading: () => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: SizedBox(
                  width: SpacingTokens.xxl,
                  height: SpacingTokens.xxl,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.onSurfaceFaint),
                ),
              ),
            ),
            error: (_, __) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(l10n.errorGeneric,
                    style: AppTextTheme.body
                        .copyWith(color: colors.onSurfaceMuted)),
              ),
            ),
            data: (songs) {
              final rows = _buildRows(songs);
              return SliverPadding(
                padding: EdgeInsets.only(
                  bottom: playerBarInset(context,
                      miniPlayerVisible: miniPlayerVisible),
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final row = rows[i];
                      if (row.discHeader != null) {
                        return _DiscHeader(
                          disc: row.discHeader!,
                          count: row.discCount,
                          duration: row.discDuration,
                          accent: accent,
                        );
                      }
                      final song = row.song!;
                      return _AlbumTrackRow(
                        song: song,
                        trackNumber: row.trackNumber,
                        accent: accent,
                        onTap: () => ref
                            .read(audioControllerProvider)
                            .playQueue(songs, startIndex: row.queueIndex),
                        onMore: () => showSongActions(context, song),
                      );
                    },
                    childCount: rows.length,
                  ),
                ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }

  /// `artist · year · N songs · total duration` (year omitted when unknown).
  String _metaLine(AppLocalizations l10n, List<Song> songs) {
    final total = songs.fold<Duration>(
        Duration.zero, (sum, s) => sum + s.duration);
    final parts = <String>[
      album.artist,
      if (album.year != null) album.year!.toString(),
      l10n.songsCount(album.songCount),
      total.humanized,
    ];
    return parts.join(' · ');
  }

  /// Flattens the album into list rows. When more than one disc number is
  /// present, a disc header row (with the disc's own track count + duration)
  /// precedes each disc's tracks, and track numbers restart per disc — matching
  /// how multi-CD albums read elsewhere. The queue (and therefore [Song] start
  /// indices) stays the full album in original order. Each track carries its
  /// display number: the file's real track number, or its running position when
  /// the tag is missing.
  List<_Row> _buildRows(List<Song> songs) {
    final discs = <int>{for (final s in songs) s.discNumber ?? 1};
    if (discs.length < 2) {
      return [
        for (var i = 0; i < songs.length; i++)
          _Row.song(songs[i],
              queueIndex: i, trackNumber: songs[i].trackNumber ?? (i + 1)),
      ];
    }

    final rows = <_Row>[];
    final sortedDiscs = discs.toList()..sort();
    for (final disc in sortedDiscs) {
      final discIndices = [
        for (var i = 0; i < songs.length; i++)
          if ((songs[i].discNumber ?? 1) == disc) i,
      ];
      final discDuration = discIndices.fold<Duration>(
          Duration.zero, (sum, i) => sum + songs[i].duration);
      rows.add(_Row.header(disc,
          count: discIndices.length, duration: discDuration));
      for (var pos = 0; pos < discIndices.length; pos++) {
        final i = discIndices[pos];
        rows.add(_Row.song(songs[i],
            queueIndex: i, trackNumber: songs[i].trackNumber ?? (pos + 1)));
      }
    }
    return rows;
  }
}

/// The album hero: artwork fills the backdrop under a top→bottom scrim that
/// fades to the page background, with the album name + meta line bottom-left.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.album,
    required this.background,
    required this.meta,
    required this.accent,
  });

  final Album album;
  final Color background;
  final String? meta;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AuraArtwork(
          seed: album.artworkSeed,
          size: double.maxFinite,
          borderRadius: BorderRadius.zero,
          hasArtwork: album.hasArtwork,
          artworkId: album.firstSongId,
        ),
        // Subtle palette hue wash — picks up the album's dominant colour.
        DecoratedBox(
          decoration: BoxDecoration(color: accent.withOpacity(0.08)),
        ),
        // Top vignette so back button stays legible.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.black.withOpacity(0.38),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Bottom melt: artwork dissolves into the wash-tinted page background.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.50, 1.0],
              colors: [
                Colors.transparent,
                background.withOpacity(0.65),
                background,
              ],
            ),
          ),
        ),
        Positioned(
          left: SpacingTokens.xl,
          right: SpacingTokens.xl,
          bottom: SpacingTokens.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                album.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.display.copyWith(
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              if (meta != null) ...[
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.body
                      .copyWith(color: Colors.white.withOpacity(0.82)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Pill action button — accent-fill for the primary action, glass-surface
/// outline for the secondary. Uses PressScale (no Material ink ripple).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = filled ? Colors.white : colors.onSurface;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? accent : colors.surfaceElevated,
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

class _Row {
  const _Row.song(Song this.song,
      {required this.queueIndex, required this.trackNumber})
      : discHeader = null,
        discCount = 0,
        discDuration = Duration.zero;
  const _Row.header(int this.discHeader,
      {required int count, required Duration duration})
      : song = null,
        queueIndex = -1,
        trackNumber = 0,
        discCount = count,
        discDuration = duration;

  final Song? song;
  final int queueIndex;

  /// Display number shown for a track row (real track number, else position).
  final int trackNumber;

  final int? discHeader;
  final int discCount;
  final Duration discDuration;
}

/// A Samsung-style disc separator: an accent "Disc N" chip with the disc's own
/// track count and duration, and a hairline rule filling the rest of the row.
class _DiscHeader extends StatelessWidget {
  const _DiscHeader({
    required this.disc,
    required this.count,
    required this.duration,
    required this.accent,
  });
  final int disc;
  final int count;
  final Duration duration;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.xl,
        SpacingTokens.lg,
        SpacingTokens.xl,
        SpacingTokens.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: RadiusTokens.brSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.album, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  l10n.discN(disc),
                  style: AppTextTheme.caption.copyWith(
                    color: accent,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          Text(
            '${l10n.songsCount(count)} · ${duration.humanized}',
            style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(child: Divider(color: colors.divider, height: 1)),
        ],
      ),
    );
  }
}

/// A numbered album track row: track number (or a now-playing indicator) ·
/// title · duration · overflow. No per-row thumbnail or "artist · album"
/// subtitle — in an album context those are identical on every row, so they're
/// dropped for a cleaner, tracklist-style read. The current track is tinted and
/// titled in the album's accent.
class _AlbumTrackRow extends ConsumerWidget {
  const _AlbumTrackRow({
    required this.song,
    required this.trackNumber,
    required this.accent,
    required this.onTap,
    required this.onMore,
  });

  final Song song;
  final int trackNumber;
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
      semanticLabel: song.title,
      child: Container(
        color: isCurrent ? accent.withOpacity(0.08) : Colors.transparent,
        padding: const EdgeInsets.only(left: SpacingTokens.xl),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Center(
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
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SpacingTokens.md),
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.title.copyWith(
                    color: isCurrent ? accent : colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
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
