import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../domain/models/library_sort.dart';
import '../../../domain/models/song.dart';
import '../../providers/async_value_x.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/selection_providers.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/library/library_controls.dart';
import '../../widgets/library/selection_bar.dart';
import '../../widgets/library/song_compact_tile.dart';
import '../../widgets/library/song_grid_tile.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/section_header.dart';
import '../settings/settings_page.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  static const String _listId = SelectionScopes.library;

  void _play(WidgetRef ref, List<Song> queue, int index) {
    ref.read(audioControllerProvider).playQueue(queue, startIndex: index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(sortedSongsProvider);
    final sort = ref.watch(librarySortProvider);
    final mode = ref.watch(libraryDisplayModeProvider);
    final miniPlayerVisible = ref.watch(hasMediaProvider);
    final selecting = ref.watch(
        selectionProvider(_listId).select((s) => s.active));
    final count = songsAsync.maybeWhen(data: (s) => s.length, orElse: () => 0);
    final allSongs = songsAsync.valueOrNull ?? const <Song>[];

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selecting)
            SelectionBar(listId: _listId, allSongs: allSongs)
          else
            SectionHeader(
              title: l10n.tabLibrary,
              subtitle: count > 0 ? l10n.songsCount(count) : null,
              actions: [
                DisplayModeButton(
                  mode: mode,
                  onChanged: (m) =>
                      ref.read(libraryDisplayModeProvider.notifier).state = m,
                ),
                IconButton(
                  tooltip: l10n.sortLabel,
                  onPressed: () => showSortSheet(
                    context,
                    current: sort,
                    onChanged: (s) =>
                        ref.read(librarySortProvider.notifier).state = s,
                  ),
                  icon: const Icon(Icons.sort),
                ),
                IconButton(
                  tooltip: l10n.settings,
                  onPressed: () => openSettings(context),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          Expanded(
            child: AsyncStateView<List<Song>>(
              value: songsAsync.like,
              isEmpty: (s) => s.isEmpty,
              emptyMessage: l10n.libraryEmpty,
              onRetry: () => ref.invalidate(songsProvider),
              data: (songs) => _SongsBody(
                songs: songs,
                mode: mode,
                miniPlayerVisible: miniPlayerVisible,
                onPlayAt: (i) => _play(ref, songs, i),
              ),
            ),
          ),
        ],
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

    switch (mode) {
      case DisplayMode.list:
        return ListView.builder(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.md, 0, SpacingTokens.md, bottom),
          itemCount: songs.length,
          itemBuilder: (_, i) => SongListTile(
            song: songs[i],
            selected: selectedOf(songs[i]),
            onTap: () => onTapAt(i),
            onLongPress: () => onLongPress(songs[i]),
            onMore: () => showSongActions(context, songs[i]),
          ),
        );
      case DisplayMode.compact:
        return ListView.builder(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.sm, 0, SpacingTokens.sm, bottom),
          itemCount: songs.length,
          itemBuilder: (_, i) => SongCompactTile(
            song: songs[i],
            selected: selectedOf(songs[i]),
            onTap: () => onTapAt(i),
            onLongPress: () => onLongPress(songs[i]),
          ),
        );
      case DisplayMode.grid:
        return GridView.builder(
          padding:
              EdgeInsets.fromLTRB(SpacingTokens.lg, 0, SpacingTokens.lg, bottom),
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
        );
    }
  }
}
