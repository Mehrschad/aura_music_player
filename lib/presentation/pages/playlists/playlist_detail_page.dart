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
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_covers_provider.dart';
import '../../providers/playlist_providers.dart';
import '../../providers/smart_playlist_providers.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/player_bar_inset.dart';
import '../tag_editor/tag_editor_page.dart';
import 'add_songs_page.dart';
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

    // Tint the page from the first song's artwork — but via the cheap,
    // synchronous seed wash, not the async cover-palette extraction. Watching
    // the async palette here made the background flash (and dropped frames)
    // partway through the push, which read as a janky, "jumping" transition.
    final firstSong = songsAsync.valueOrNull?.isNotEmpty == true
        ? songsAsync.valueOrNull!.first
        : null;
    final pageBackground = firstSong == null
        ? colors.background
        : Color.alphaBlend(
            SeedPalette.wash(firstSong.artworkSeed).withOpacity(0.18),
            colors.background);

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
        // Editable playlists always render the header (with its "Add songs"
        // button) even when empty, so a freshly created playlist can be filled.
        isEmpty: (s) => s.isEmpty && !_editable,
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
              onAddSongs: _editable
                  ? () => openAddSongs(context, playlistId!)
                  : null,
            ),
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SpacingTokens.xxl),
                        child: Text(
                          'This playlist is empty.\nTap "Add songs" to fill it.',
                          textAlign: TextAlign.center,
                          style: AppTextTheme.body
                              .copyWith(color: colors.onSurfaceFaint),
                        ),
                      ),
                    )
                  : _editable
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
                        onMore: () => showSongActions(context, songs[i]),
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
    this.onAddSongs,
  });

  final int count;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  /// When non-null (editable playlists), shows an "Add songs" button.
  final VoidCallback? onAddSongs;

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
          if (onAddSongs != null) ...[
            const SizedBox(height: SpacingTokens.sm),
            PressScale(
              onTap: onAddSongs,
              pressedScale: 0.98,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.12),
                  borderRadius: RadiusTokens.brPill,
                  border: Border.all(color: colors.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 20, color: colors.accent),
                    const SizedBox(width: SpacingTokens.sm),
                    Text('Add songs',
                        style: AppTextTheme.action
                            .copyWith(color: colors.accent)),
                  ],
                ),
              ),
            ),
          ],
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_vert,
                      size: 20, color: colors.onSurfaceFaint),
                  onPressed: () => showSongActions(
                    context,
                    song,
                    onRemove: () => repo.removeSongAt(playlistId, i),
                  ),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: Icon(Icons.drag_handle, color: colors.onSurfaceFaint),
                ),
              ],
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
          case 'cover':
            await pickPlaylistCover(ref, playlistId!);
          case 'removecover':
            ref.read(playlistCoversProvider.notifier).removeCover(playlistId!);
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
          const PopupMenuItem(value: 'cover', child: Text('Change cover')),
          if (ref.watch(playlistCoversProvider).containsKey(playlistId))
            const PopupMenuItem(
                value: 'removecover', child: Text('Remove cover')),
          PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
        ],
      ],
    );
  }
}
