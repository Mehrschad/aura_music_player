import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/playlist.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../../providers/smart_playlist_providers.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/section_header.dart';
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
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final smartPlaylists =
        ref.watch(smartPlaylistsProvider).valueOrNull ?? const [];
    final repo = ref.read(playlistRepositoryProvider);

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
            child: Text(l10n.playlistsMadeForYou,
                style: AppTextTheme.title.copyWith(color: colors.onSurfaceMuted)),
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
                    },
                    icon: _autoIcon(type),
                    count: ref
                            .watch(autoPlaylistSongsProvider(type))
                            .valueOrNull
                            ?.length ??
                        0,
                    onTap: () => openAutoPlaylist(context, type),
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
                Text(l10n.playlistsYours,
                    style: AppTextTheme.title
                        .copyWith(color: colors.onSurfaceMuted)),
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
                onTap: () => openUserPlaylist(context, p.id),
              ),

          const SizedBox(height: SpacingTokens.lg),

          // Smart playlists (rule-based, auto-updating).
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.xl, 0, SpacingTokens.sm, SpacingTokens.xs),
            child: Row(
              children: [
                Text(l10n.smartPlaylists,
                    style: AppTextTheme.title
                        .copyWith(color: colors.onSurfaceMuted)),
                const Spacer(),
                IconButton(
                  tooltip: l10n.smartPlaylistNew,
                  icon: Icon(Icons.auto_awesome, color: colors.onSurface),
                  onPressed: () => openSmartPlaylistEditor(context),
                ),
              ],
            ),
          ),
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

class _AutoCard extends StatelessWidget {
  const _AutoCard({
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return PressScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brMd,
          border: Border.all(
            color: colors.onSurface.withOpacity(0.06),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: Row(
          children: [
            Icon(icon, color: colors.onSurface, size: 22),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextTheme.title.copyWith(color: colors.onSurface)),
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
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brXs,
        ),
        child: Icon(Icons.auto_awesome, color: colors.onSurfaceMuted),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.title.copyWith(color: colors.onSurface)),
      subtitle: Text(l10n.songsCount(count),
          style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint)),
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceFaint),
      onTap: onTap,
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: RadiusTokens.brXs,
        ),
        child: Icon(Icons.queue_music, color: colors.onSurfaceMuted),
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
