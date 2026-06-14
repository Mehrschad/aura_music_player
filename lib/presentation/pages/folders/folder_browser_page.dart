import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/library/path_utils.dart';
import '../../../domain/models/music_folder.dart';
import '../../providers/folder_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/glass/glass_surface.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/section_header.dart';

/// Opens the hierarchical folder browser inside the current navigator.
void openFolderBrowser(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const FolderBrowserPage()),
  );
}

class FolderBrowserPage extends ConsumerWidget {
  const FolderBrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final root = ref.watch(folderRootProvider);
    final path = ref.watch(folderBrowsePathProvider) ?? root;
    final listing = ref.watch(folderListingProvider);
    final miniVisible = ref.watch(hasMediaProvider);

    final atRoot = path == root || path.isEmpty;

    void goTo(String? p) =>
        ref.read(folderBrowsePathProvider.notifier).state = p;

    return PopScope(
      canPop: atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !atRoot) goTo(PathUtils.parentDir(path));
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: l10n.folders,
                subtitle: listing.valueOrNull == null
                    ? null
                    : l10n.songsCount(
                        ref.watch(folderSongsProvider(path)).length),
                actions: [
                  IconButton(
                    tooltip: l10n.playAll,
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => _playFolder(ref, path, shuffle: false),
                  ),
                  IconButton(
                    tooltip: l10n.shuffleAll,
                    icon: const Icon(Icons.shuffle_rounded),
                    onPressed: () => _playFolder(ref, path, shuffle: true),
                  ),
                ],
              ),
              _Breadcrumb(root: root, path: path, onTap: goTo),
              Expanded(
                child: listing.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(child: Text(l10n.errorGeneric)),
                  data: (data) {
                    if (data.isEmpty) {
                      return Center(child: Text(l10n.libraryEmpty));
                    }
                    final bottom = playerBarInset(context,
                        miniPlayerVisible: miniVisible);
                    return ListView(
                      padding: EdgeInsets.only(bottom: bottom),
                      children: [
                        for (final f in data.folders)
                          _FolderRow(
                            folder: f,
                            onTap: () => goTo(f.path),
                            onLongPress: () =>
                                _showFolderActions(context, ref, f),
                          ),
                        for (var i = 0; i < data.songs.length; i++)
                          SongListTile(
                            song: data.songs[i],
                            onTap: () => ref
                                .read(audioControllerProvider)
                                .playQueue(data.songs, startIndex: i),
                            onMore: () =>
                                showSongActions(context, data.songs[i]),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playFolder(WidgetRef ref, String path, {required bool shuffle}) {
    final songs = ref.read(folderSongsProvider(path));
    if (songs.isEmpty) return;
    final ctrl = ref.read(audioControllerProvider);
    ctrl.setShuffle(shuffle);
    ctrl.playQueue(songs);
  }

  Future<void> _showFolderActions(
      BuildContext context, WidgetRef ref, MusicFolder folder) {
    final l10n = AppLocalizations.of(context);
    final songs = ref.read(folderSongsProvider(folder.path));
    final ctrl = ref.read(audioControllerProvider);
    final messenger = ScaffoldMessenger.of(context);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.md),
          child: GlassSurface(
            borderRadius: RadiusTokens.brLg,
            intensity: GlassIntensity.strong,
            padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionTile(
                  icon: Icons.queue_play_next,
                  label: l10n.playNext,
                  onTap: () {
                    for (final s in songs.reversed) {
                      ctrl.playNext(s);
                    }
                    Navigator.pop(sheetCtx);
                    messenger.showSnackBar(
                        SnackBar(content: Text(l10n.addedToQueue)));
                  },
                ),
                _ActionTile(
                  icon: Icons.add_to_queue,
                  label: l10n.addToQueue,
                  onTap: () {
                    for (final s in songs) {
                      ctrl.addToQueue(s);
                    }
                    Navigator.pop(sheetCtx);
                    messenger.showSnackBar(
                        SnackBar(content: Text(l10n.addedToQueue)));
                  },
                ),
                _ActionTile(
                  icon: Icons.playlist_add,
                  label: l10n.addAsPlaylist,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    showAddSongsToPlaylist(
                        context, [for (final s in songs) s.id]);
                  },
                ),
                _ActionTile(
                  icon: Icons.visibility_off_outlined,
                  label: l10n.excludeFromLibrary,
                  destructive: true,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .addExcludedFolder(folder.path);
                    Navigator.pop(sheetCtx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.root, required this.path, required this.onTap});
  final String root;
  final String path;
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Segments shown relative to the library root.
    final rootSegs = PathUtils.segments(root);
    final allSegs = PathUtils.segments(path);
    final crumbs = allSegs.length <= rootSegs.length
        ? <String>[]
        : allSegs.sublist(rootSegs.length);

    String pathForCrumb(int i) =>
        '${PathUtils.separator}${allSegs.sublist(0, rootSegs.length + i + 1).join(PathUtils.separator)}';

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
        children: [
          _Crumb(
            label: PathUtils.basename(root).isEmpty
                ? PathUtils.storageLabel(root)
                : PathUtils.basename(root),
            onTap: () => onTap(null),
            active: crumbs.isEmpty,
          ),
          for (var i = 0; i < crumbs.length; i++) ...[
            Icon(Icons.chevron_right_rounded,
                size: 16, color: colors.onSurfaceFaint),
            _Crumb(
              label: crumbs[i],
              onTap: () => onTap(pathForCrumb(i)),
              active: i == crumbs.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.onTap, required this.active});
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Center(
        child: Text(
          label,
          style: AppTextTheme.caption.copyWith(
            color: active ? colors.onSurface : colors.onSurfaceMuted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.onTap,
    required this.onLongPress,
  });
  final MusicFolder folder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final art = folder.displaySong;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: SizedBox(
        width: 44,
        height: 44,
        child: art == null
            ? Icon(Icons.folder_rounded, color: colors.onSurfaceMuted)
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: RadiusTokens.brXs,
                    child: AuraArtwork(
                        seed: art.artworkSeed,
                        size: 44,
                        hasArtwork: art.hasArtwork,
                        artworkId: int.tryParse(art.id)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(Icons.folder,
                        size: 16, color: colors.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
      ),
      title: Text(folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.body.copyWith(color: colors.onSurface)),
      subtitle: Text(
        '${l10n.songsCount(folder.trackCount)} · ${folder.totalDuration.clock}',
        style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
      ),
      trailing:
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceFaint),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? Colors.redAccent : colors.onSurface;
    return ListTile(
      leading: Icon(icon,
          color: destructive ? Colors.redAccent : colors.onSurfaceMuted),
      title: Text(label, style: AppTextTheme.body.copyWith(color: color)),
      onTap: onTap,
    );
  }
}
