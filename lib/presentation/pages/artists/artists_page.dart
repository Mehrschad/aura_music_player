import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../domain/models/artist.dart';
import 'artist_detail_page.dart';
import '../../providers/artist_favorites_providers.dart';
import '../../providers/async_value_x.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/library/artist_list_tile.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/section_header.dart';

class ArtistsPage extends ConsumerWidget {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final favoritesOnly = ref.watch(artistsFavoritesOnlyProvider);
    final favSet = ref.watch(artistFavoritesProvider);
    // Filter to favourites when the toggle is on, keeping the async envelope so
    // loading/error/empty still render through AsyncStateView.
    final artistsAsync = ref.watch(artistsProvider).whenData((artists) =>
        favoritesOnly
            ? [for (final a in artists) if (favSet.contains(a.id)) a]
            : artists);
    final count =
        artistsAsync.maybeWhen(data: (a) => a.length, orElse: () => 0);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l10n.tabArtists,
            subtitle: count > 0 ? l10n.artistsCount(count) : null,
            actions: [
              IconButton(
                tooltip:
                    favoritesOnly ? 'Show all artists' : 'Favourite artists',
                icon: Icon(
                  favoritesOnly ? Icons.favorite : Icons.favorite_border,
                  color: favoritesOnly ? colors.favorite : null,
                ),
                onPressed: () => ref
                    .read(artistsFavoritesOnlyProvider.notifier)
                    .state = !favoritesOnly,
              ),
            ],
          ),
          Expanded(
            child: AsyncStateView<List<Artist>>(
              value: artistsAsync.like,
              isEmpty: (a) => a.isEmpty,
              emptyMessage: favoritesOnly
                  ? 'No favourite artists yet'
                  : l10n.libraryEmpty,
              emptyIcon:
                  favoritesOnly ? Icons.favorite_border : Icons.person_outline,
              onRetry: () => ref.invalidate(songsProvider),
              data: (artists) => ListView.builder(
                padding: EdgeInsets.fromLTRB(
                    SpacingTokens.md,
                    0,
                    SpacingTokens.md,
                    playerBarInset(context,
                        miniPlayerVisible: ref.watch(hasMediaProvider))),
                itemCount: artists.length,
                itemBuilder: (_, i) {
                  final a = artists[i];
                  final subtitle =
                      '${l10n.albumsCount(a.albumCount)} \u00b7 ${l10n.songsCount(a.songCount)}';
                  return ArtistListTile(
                    artist: a,
                    subtitle: subtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ArtistDetailPage(artist: a),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
