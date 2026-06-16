import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../domain/models/artist.dart';
import 'artist_detail_page.dart';
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
    final artistsAsync = ref.watch(artistsProvider);
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
          ),
          Expanded(
            child: AsyncStateView<List<Artist>>(
              value: artistsAsync.like,
              isEmpty: (a) => a.isEmpty,
              emptyMessage: l10n.libraryEmpty,
              emptyIcon: Icons.person_outline,
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
