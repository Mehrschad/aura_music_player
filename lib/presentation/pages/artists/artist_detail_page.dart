import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../providers/artist_bio_providers.dart';
import '../../providers/artist_favorites_providers.dart';
import '../../providers/cover_palette_provider.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
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

    // iOS 27: entire page background gets a gentle wash tint so the artwork
    // colour bleeds through the whole scroll area — not just the header.
    final pageBackground =
        Color.alphaBlend(wash.withOpacity(0.10), colors.background);

    // Half-screen hero: the artwork fills the top 50 % of the display.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = screenHeight * 0.50;

    return Scaffold(
      backgroundColor: pageBackground,
      body: CustomScrollView(
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
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(
                SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.lg),
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

          // ── Top Songs ───────────────────────────────────────────────────
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
              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SpacingTokens.xl,
                        SpacingTokens.md,
                        SpacingTokens.xl,
                        SpacingTokens.sm,
                      ),
                      child: Text(
                        l10n.tabSongs.toUpperCase(),
                        style: AppTextTheme.caption.copyWith(
                          color: colors.onSurfaceFaint,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => SongListTile(
                        song: songs[i],
                        onTap: () => ref
                            .read(audioControllerProvider)
                            .playQueue(songs, startIndex: i),
                        onMore: () => showSongActions(context, songs[i]),
                      ),
                      childCount: songs.length,
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Albums, each its own card in a horizontal rail ──────────────
          albumsAsync.maybeWhen(
            data: (albums) => albums.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverToBoxAdapter(
                    child: _AlbumsRail(albums: albums),
                  ),
            orElse: () =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: playerBarInset(context,
                  miniPlayerVisible: miniPlayerVisible),
            ),
          ),
        ],
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

/// Horizontal rail of the artist's albums — one tappable card per album.
class _AlbumsRail extends StatelessWidget {
  const _AlbumsRail({required this.albums});
  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.xl,
            SpacingTokens.md,
            SpacingTokens.xl,
            SpacingTokens.sm,
          ),
          child: Text(
            l10n.tabAlbums,
            style: AppTextTheme.caption.copyWith(
              color: colors.onSurfaceFaint,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
            itemCount: albums.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: SpacingTokens.md),
            itemBuilder: (context, i) {
              final album = albums[i];
              return PressScale(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlbumDetailPage(album: album),
                  ),
                ),
                semanticLabel: album.name,
                child: SizedBox(
                  width: 132,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuraArtwork(
                        seed: album.artworkSeed,
                        size: 132,
                        borderRadius: RadiusTokens.brLg,
                        hasArtwork: album.hasArtwork,
                        artworkId: album.firstSongId,
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.body.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        album.year?.toString() ??
                            l10n.songsCount(album.songCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextTheme.caption
                            .copyWith(color: colors.onSurfaceMuted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
