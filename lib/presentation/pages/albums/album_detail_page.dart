import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(albumSongsProvider(album.id));
    final miniPlayerVisible = ref.watch(hasMediaProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: colors.background,
            expandedHeight: 260,
            pinned: true,
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
              titlePadding: const EdgeInsetsDirectional.fromSTEB(
                SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.md),
              title: Text(
                album.name,
                style: AppTextTheme.title.copyWith(color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AuraArtwork(
                    seed: album.artworkSeed,
                    size: double.maxFinite,
                    borderRadius: BorderRadius.zero,
                    hasArtwork: album.hasArtwork,
                    artworkId: album.firstSongId,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Artist + song count + Play button row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.xl,
                SpacingTokens.sm,
                SpacingTokens.xl,
                SpacingTokens.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextTheme.body
                              .copyWith(color: colors.onSurfaceMuted),
                        ),
                        Text(
                          l10n.songsCount(album.songCount),
                          style: AppTextTheme.caption
                              .copyWith(color: colors.onSurfaceFaint),
                        ),
                      ],
                    ),
                  ),
                  songsAsync.maybeWhen(
                    data: (songs) => songs.isEmpty
                        ? const SizedBox.shrink()
                        : FilledButton.icon(
                            onPressed: () => ref
                                .read(audioControllerProvider)
                                .playQueue(songs),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.playAll),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
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
