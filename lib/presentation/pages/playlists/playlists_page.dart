import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/aurora_colors.dart';
import '../../../core/constants/icon_sizes.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/playlist.dart';
import '../../../domain/models/song.dart';
import '../../../domain/taste/smart_collection.dart';
import '../../providers/discovery_prefs_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../../providers/smart_collections_provider.dart';
import '../../providers/smart_playlist_providers.dart';
import '../../widgets/library/collection_actions.dart';
import '../../widgets/library/collection_cover.dart';
import '../../widgets/library/playlist_cover.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/section_header.dart';
import '../library/collection_detail_page.dart';
import 'playlist_detail_page.dart';
import 'playlist_dialogs.dart';
import 'smart_playlist_editor_page.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  IconData _autoIcon(AutoPlaylist t) => switch (t) {
        AutoPlaylist.recentlyAdded => Icons.fiber_new_outlined,
        AutoPlaylist.mostPlayed => Icons.local_fire_department_outlined,
        AutoPlaylist.recentlyPlayed => Icons.history,
        AutoPlaylist.favorites => Icons.favorite_outline,
        AutoPlaylist.topRated => Icons.star_outline_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final smartPlaylists =
        ref.watch(smartPlaylistsProvider).valueOrNull ?? const [];
    // Taste-based collections (For You / Mix / Mood / Hidden Gems …), each
    // savable into a real playlist or dismissable.
    final smartCollections = ref.watch(smartCollectionsProvider);
    final repo = ref.read(playlistRepositoryProvider);

    // Resolve song ids → songs so playlist covers can draw an art mosaic.
    final songsById = {
      for (final s in ref.watch(songsProvider).valueOrNull ?? const <Song>[])
        s.id: s,
    };
    List<Song> coverSongs(Playlist p) => [
          for (final id in p.songIds.take(8))
            if (songsById[id] != null) songsById[id]!,
        ].take(4).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(
            bottom: playerBarInset(context,
                miniPlayerVisible: ref.watch(hasMediaProvider))),
        children: [
          SectionHeader(title: l10n.tabPlaylists),

          // "Made for you" auto playlists.
          Padding(
            padding: const EdgeInsets.fromLTRB(SpacingTokens.xl, 0,
                SpacingTokens.xl, SpacingTokens.sm),
            child: _SubHead(text: l10n.playlistsMadeForYou),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: SpacingTokens.md,
              crossAxisSpacing: SpacingTokens.md,
              childAspectRatio: 2.4,
              children: [
                for (final type in AutoPlaylist.values)
                  _AutoCard(
                    label: switch (type) {
                      AutoPlaylist.recentlyAdded => l10n.autoRecentlyAdded,
                      AutoPlaylist.mostPlayed => l10n.autoMostPlayed,
                      AutoPlaylist.recentlyPlayed => l10n.autoRecentlyPlayed,
                      AutoPlaylist.favorites => l10n.autoFavorites,
                      AutoPlaylist.topRated => l10n.autoTopRated,
                    },
                    icon: _autoIcon(type),
                    count: ref
                            .watch(autoPlaylistSongsProvider(type))
                            .valueOrNull
                            ?.length ??
                        0,
                    onTap: () => openAutoPlaylist(context, type),
                    isFavorites: type == AutoPlaylist.favorites,
                  ),
              ],
            ),
          ),

          const SizedBox(height: SpacingTokens.lg),

          // "Your playlists" with create.
          Padding(
            padding: const EdgeInsets.fromLTRB(SpacingTokens.xl, 0,
                SpacingTokens.sm, SpacingTokens.xs),
            child: Row(
              children: [
                _SubHead(text: l10n.playlistsYours),
                const Spacer(),
                IconButton(
                  tooltip: l10n.playlistNew,
                  icon: Icon(Icons.add, color: colors.onSurface),
                  onPressed: () async {
                    final name = await promptPlaylistName(context);
                    if (name != null) await repo.create(name);
                  },
                ),
              ],
            ),
          ),

          if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.xl),
              child: Text(l10n.playlistEmpty,
                  style: AppTextTheme.body
                      .copyWith(color: colors.onSurfaceFaint)),
            )
          else
            for (final p in playlists)
              _PlaylistRow(
                playlist: p,
                coverSongs: coverSongs(p),
                onTap: () => openUserPlaylist(context, p.id),
              ),

          const SizedBox(height: SpacingTokens.lg),

          // Smart playlists (rule-based, auto-updating).
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.xl, 0, SpacingTokens.sm, SpacingTokens.xs),
            child: Row(
              children: [
                _SubHead(text: l10n.smartPlaylists),
                const Spacer(),
                IconButton(
                  tooltip: l10n.smartPlaylistNew,
                  icon: Icon(Icons.auto_awesome, color: colors.onSurface),
                  onPressed: () => openSmartPlaylistEditor(context),
                ),
              ],
            ),
          ),
          // Taste-based suggestions — save one to keep it, dismiss to hide it.
          for (final c in smartCollections)
            _CollectionRow(
              collection: c,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CollectionDetailPage(collection: c),
                ),
              ),
              onSave: () => saveCollectionAsPlaylist(context, ref, c),
              onDismiss: () => ref
                  .read(hiddenCollectionsProvider.notifier)
                  .add(c.id),
            ),
          // The user's own rule-based smart playlists.
          for (final sp in smartPlaylists)
            _SmartRow(
              name: sp.name,
              count: ref
                      .watch(smartPlaylistSongsProvider(sp.id))
                      .valueOrNull
                      ?.length ??
                  0,
              onTap: () => openSmartPlaylist(context, sp.id),
            ),
        ],
      ),
    );
  }
}

/// Uppercase section subhead (13/600, faint, +0.3 tracking) per the DS.
class _SubHead extends StatelessWidget {
  const _SubHead({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextTheme.body.copyWith(
        color: context.colors.onSurfaceFaint,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _AutoCard extends StatelessWidget {
  const _AutoCard({
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
    this.isFavorites = false,
  });

  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final bool isFavorites;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    // Favorites uses a favorite-tinted box; others a deeper surface box.
    final iconBg = isFavorites
        ? colors.favorite.withOpacity(0.16)
        : colors.surface;
    final iconColor = isFavorites ? colors.favorite : colors.onSurface;
    final iconData = isFavorites ? Icons.favorite : icon;

    return PressScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brMd,
          border: Border.all(color: colors.divider),
        ),
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: RadiusTokens.brSm,
              ),
              child: Icon(iconData, color: iconColor, size: IconSizes.md),
            ),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.title.copyWith(color: colors.onSurface)),
                  Text(l10n.songsCount(count),
                      style: AppTextTheme.caption
                          .copyWith(color: colors.onSurfaceFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartRow extends StatelessWidget {
  const _SmartRow(
      {required this.name, required this.count, required this.onTap});

  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          gradient: AuroraColors.gradientSoft,
          borderRadius: RadiusTokens.brSm,
        ),
        child: Icon(Icons.auto_awesome, color: colors.onSurface),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.title.copyWith(color: colors.onSurface)),
      subtitle: Text(l10n.smartPlaylistAutoCount(count),
          style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint)),
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceFaint),
      onTap: onTap,
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.coverSongs,
    required this.onTap,
  });

  final Playlist playlist;
  final List<Song> coverSongs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: PlaylistCover(
        seed: playlist.id,
        songs: coverSongs,
        size: 48,
      ),
      title: Text(playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.title.copyWith(color: colors.onSurface)),
      subtitle: Text(l10n.songsCount(playlist.length),
          style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint)),
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceFaint),
      onTap: onTap,
    );
  }
}

/// A taste-based smart collection row: tap to open, save to keep it as a real
/// playlist (it then shows under "Your playlists"), or dismiss to hide it.
class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.collection,
    required this.onOpen,
    required this.onSave,
    required this.onDismiss,
  });

  final SmartCollection collection;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
      leading: SizedBox(
        width: 48,
        height: 48,
        child: CollectionCover.collection(collection,
            size: 48, radius: RadiusTokens.sm),
      ),
      title: Text(collection.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.title.copyWith(color: colors.onSurface)),
      subtitle: Text(collection.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).saveButtonLabel,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.bookmark_add_outlined, color: colors.accent),
            onPressed: onSave,
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, color: colors.onSurfaceFaint),
            onPressed: onDismiss,
          ),
        ],
      ),
      onTap: onOpen,
    );
  }
}
