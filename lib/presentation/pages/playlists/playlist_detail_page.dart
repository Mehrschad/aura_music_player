import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/library/playlist_logic.dart';
import '../../../domain/models/playlist.dart';
import '../../../domain/models/song.dart';
import '../../providers/async_value_x.dart';
import '../../providers/cover_palette_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../../providers/smart_playlist_providers.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/player_bar_inset.dart';
import '../tag_editor/tag_editor_page.dart';
import 'playlist_dialogs.dart';
import 'smart_playlist_editor_page.dart';

String autoPlaylistLabel(AutoPlaylist type, AppLocalizations l10n) =>
    switch (type) {
      AutoPlaylist.recentlyAdded => l10n.autoRecentlyAdded,
      AutoPlaylist.mostPlayed => l10n.autoMostPlayed,
      AutoPlaylist.recentlyPlayed => l10n.autoRecentlyPlayed,
      AutoPlaylist.favorites => l10n.autoFavorites,
      AutoPlaylist.topRated => l10n.autoTopRated,
    };

Future<void> openUserPlaylist(BuildContext context, String id) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PlaylistDetailPage.user(id),
  ));
}

Future<void> openAutoPlaylist(BuildContext context, AutoPlaylist type) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PlaylistDetailPage.auto(type),
  ));
}

Future<void> openSmartPlaylist(BuildContext context, String id) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PlaylistDetailPage.smart(id),
  ));
}

class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage.user(String this.playlistId)
      : auto = null,
        smartId = null,
        super(key: null);
  const PlaylistDetailPage.auto(AutoPlaylist this.auto)
      : playlistId = null,
        smartId = null,
        super(key: null);
  const PlaylistDetailPage.smart(String this.smartId)
      : playlistId = null,
        auto = null,
        super(key: null);

  final String? playlistId;
  final AutoPlaylist? auto;
  final String? smartId;

  bool get _editable => playlistId != null;
  bool get _isSmart => smartId != null;

  void _play(WidgetRef ref, List<Song> songs, int index) {
    if (songs.isEmpty) return;
    ref.read(audioControllerProvider).playQueue(songs, startIndex: index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    final songsAsync = _editable
        ? ref.watch(userPlaylistSongsProvider(playlistId!))
        : _isSmart
            ? ref.watch(smartPlaylistSongsProvider(smartId!))
            : ref.watch(autoPlaylistSongsProvider(auto!));
    final title = _editable
        ? (ref.watch(playlistByIdProvider(playlistId!))?.name ?? '')
        : _isSmart
            ? (ref.watch(smartPlaylistByIdProvider(smartId!))?.name ?? '')
            : autoPlaylistLabel(auto!, l10n);

    // Derive wash tint from the first song's artwork to tint the page.
    final firstSong = songsAsync.valueOrNull?.isNotEmpty == true
        ? songsAsync.valueOrNull!.first
        : null;
    final palette = firstSong == null
        ? null
        : ref
            .watch(coverPaletteProvider((
              seed: firstSong.artworkSeed,
              hasArtwork: firstSong.hasArtwork,
              artworkId: int.tryParse(firstSong.id),
            )))
            .valueOrNull;
    final wash = palette?.wash ??
        (firstSong != null
            ? SeedPalette.wash(firstSong.artworkSeed)
            : colors.background);
    final pageBackground = firstSong == null
        ? colors.background
        : Color.alphaBlend(wash.withOpacity(0.18), colors.background);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(title,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        actions: [
          if (_isSmart)
            IconButton(
              tooltip: l10n.smartEditRules,
              icon: Icon(Icons.tune, color: colors.onSurface),
              onPressed: () {
                final def = ref.read(smartPlaylistByIdProvider(smartId!));
                if (def != null) openSmartPlaylistEditor(context, def);
              },
            ),
          AsyncStateView<List<Song>>(
            value: songsAsync.like,
            isEmpty: (_) => false,
            emptyMessage: '',
            data: (songs) => _OverflowMenu(
              editable: _editable,
              playlistId: playlistId,
              playlistName: title,
              songs: songs,
            ),
          ),
        ],
      ),
      body: AsyncStateView<List<Song>>(
        value: songsAsync.like,
        isEmpty: (s) => s.isEmpty,
        emptyMessage: l10n.playlistNoSongs,
        emptyIcon: Icons.music_note_outlined,
        onRetry: () => ref.invalidate(songsProvider),
        data: (songs) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              count: songs.length,
              onPlayAll: () => _play(ref, songs, 0),
              onShuffle: () {
                _play(ref, songs, 0);
                ref.read(audioControllerProvider).setShuffle(true);
              },
            ),
            Expanded(
              child: _editable
                  ? _ReorderableSongs(
                      playlistId: playlistId!,
                      songs: songs,
                      onPlay: (i) => _play(ref, songs, i),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(SpacingTokens.md, 0,
                          SpacingTokens.md, playerBarInset(context,
                              miniPlayerVisible:
                                  ref.watch(hasMediaProvider))),
                      itemCount: songs.length,
                      itemBuilder: (_, i) => SongListTile(
                        song: songs[i],
                        onTap: () => _play(ref, songs, i),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final int count;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final disabled = count == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SpacingTokens.xl, SpacingTokens.sm,
          SpacingTokens.xl, SpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.songsCount(count),
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint)),
          const SizedBox(height: SpacingTokens.sm),
          Row(
            children: [
              Expanded(
                child: PressScale(
                  onTap: disabled ? null : onPlayAll,
                  pressedScale: 0.96,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: disabled
                          ? colors.surfaceElevated
                          : colors.accent,
                      borderRadius: RadiusTokens.brPill,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow,
                            size: 20,
                            color: disabled
                                ? colors.onSurfaceFaint
                                : colors.onAccent),
                        const SizedBox(width: SpacingTokens.sm),
                        Text(l10n.play,
                            style: AppTextTheme.action.copyWith(
                                color: disabled
                                    ? colors.onSurfaceFaint
                                    : colors.onAccent)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Expanded(
                child: PressScale(
                  onTap: disabled ? null : onShuffle,
                  pressedScale: 0.96,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: RadiusTokens.brPill,
                      border: Border.all(color: colors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shuffle,
                            size: 20,
                            color: disabled
                                ? colors.onSurfaceFaint
                                : colors.onSurface),
                        const SizedBox(width: SpacingTokens.sm),
                        Text(l10n.shuffle,
                            style: AppTextTheme.action.copyWith(
                                color: disabled
                                    ? colors.onSurfaceFaint
                                    : colors.onSurface)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReorderableSongs extends ConsumerWidget {
  const _ReorderableSongs({
    required this.playlistId,
    required this.songs,
    required this.onPlay,
  });

  final String playlistId;
  final List<Song> songs;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.read(playlistRepositoryProvider);

    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(SpacingTokens.sm, 0, SpacingTokens.sm,
          playerBarInset(context, miniPlayerVisible: ref.watch(hasMediaProvider))),
      itemCount: songs.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        repo.reorder(playlistId, oldIndex, newIndex);
      },
      itemBuilder: (context, i) {
        final song = songs[i];
        return Dismissible(
          key: ValueKey(song.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => repo.removeSongAt(playlistId, i),
          background: Container(
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsets.only(right: SpacingTokens.xl),
            child: Icon(Icons.delete_outline, color: colors.onSurfaceMuted),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
            leading: AuraArtwork(
                seed: song.artworkSeed, size: 44, hasArtwork: song.hasArtwork),
            title: Text(song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.title.copyWith(color: colors.onSurface)),
            subtitle: Text(song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted)),
            trailing: ReorderableDragStartListener(
              index: i,
              child: Icon(Icons.drag_handle, color: colors.onSurfaceFaint),
            ),
            onTap: () => onPlay(i),
          ),
        );
      },
    );
  }
}

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({
    required this.editable,
    required this.playlistId,
    required this.playlistName,
    required this.songs,
  });

  final bool editable;
  final String? playlistId;
  final String playlistName;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(playlistRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: colors.onSurface),
      color: colors.surfaceElevated,
      onSelected: (value) async {
        switch (value) {
          case 'export':
            await Clipboard.setData(ClipboardData(text: buildM3u8(songs)));
            messenger
                .showSnackBar(SnackBar(content: Text(l10n.playlistCopied)));
          case 'edittags':
            if (songs.isNotEmpty) openTagEditor(context, songs);
          case 'rename':
            final name =
                await promptPlaylistName(context, initial: playlistName);
            if (name != null) await repo.rename(playlistId!, name);
          case 'delete':
            final ok = await confirmDeletePlaylist(context, playlistName);
            if (ok) {
              await repo.delete(playlistId!);
              if (context.mounted) Navigator.of(context).maybePop();
            }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'export', child: Text(l10n.exportM3u)),
        if (songs.isNotEmpty)
          PopupMenuItem(value: 'edittags', child: Text(l10n.editTags)),
        if (editable) ...[
          PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
        ],
      ],
    );
  }
}
