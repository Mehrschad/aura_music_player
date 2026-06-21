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
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
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
    final accent = SeedPalette.accent(album.artworkSeed);

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: colors.background,
            expandedHeight: 300,
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
                background: colors.background,
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
                        return _DiscHeader(disc: row.discHeader!);
                      }
                      final song = row.song!;
                      return SongListTile(
                        song: song,
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
  /// present, a disc header row precedes each disc's tracks; the queue (and
  /// therefore [Song] start indices) stays the full album in original order.
  List<_Row> _buildRows(List<Song> songs) {
    final discs = <int>{for (final s in songs) s.discNumber ?? 1};
    if (discs.length < 2) {
      return [
        for (var i = 0; i < songs.length; i++)
          _Row.song(songs[i], queueIndex: i),
      ];
    }

    final rows = <_Row>[];
    final sortedDiscs = discs.toList()..sort();
    for (final disc in sortedDiscs) {
      rows.add(_Row.header(disc));
      for (var i = 0; i < songs.length; i++) {
        if ((songs[i].discNumber ?? 1) == disc) {
          rows.add(_Row.song(songs[i], queueIndex: i));
        }
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
  });

  final Album album;
  final Color background;
  final String? meta;

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
        // Subtle dark at the very top (for the back button), transparent
        // middle, fading to the page background at the bottom.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.3, 1],
              colors: [
                Colors.black.withOpacity(0.25),
                Colors.transparent,
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

/// A pill action button matching the DS Button: accent fill for the primary
/// action, elevated surface with a hairline border for the secondary.
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
    return Material(
      color: filled ? accent : colors.surfaceElevated,
      borderRadius: RadiusTokens.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: RadiusTokens.brPill,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: RadiusTokens.brPill,
            border: filled
                ? null
                : Border.all(color: colors.divider),
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
      ),
    );
  }
}

class _Row {
  const _Row.song(Song this.song, {required this.queueIndex})
      : discHeader = null;
  const _Row.header(int this.discHeader)
      : song = null,
        queueIndex = -1;

  final Song? song;
  final int queueIndex;
  final int? discHeader;
}

class _DiscHeader extends StatelessWidget {
  const _DiscHeader({required this.disc});
  final int disc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.xl,
        SpacingTokens.lg,
        SpacingTokens.xl,
        SpacingTokens.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.album_outlined, size: 16, color: colors.onSurfaceFaint),
          const SizedBox(width: SpacingTokens.sm),
          Text(
            l10n.discN(disc),
            style: AppTextTheme.caption.copyWith(
              color: colors.onSurfaceFaint,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(child: Divider(color: colors.divider, height: 1)),
        ],
      ),
    );
  }
}
