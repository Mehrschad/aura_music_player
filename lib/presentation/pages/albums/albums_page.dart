import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../domain/models/album.dart';
import '../../providers/async_value_x.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/library/album_grid_tile.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/section_header.dart';
import 'album_detail_page.dart';

class AlbumsPage extends ConsumerWidget {
  const AlbumsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final albumsAsync = ref.watch(albumsProvider);
    final count = albumsAsync.maybeWhen(data: (a) => a.length, orElse: () => 0);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l10n.tabAlbums,
            subtitle: count > 0 ? l10n.albumsCount(count) : null,
          ),
          Expanded(
            child: AsyncStateView<List<Album>>(
              value: albumsAsync.like,
              isEmpty: (a) => a.isEmpty,
              emptyMessage: l10n.libraryEmpty,
              emptyIcon: Icons.album_outlined,
              onRetry: () => ref.invalidate(songsProvider),
              data: (albums) => GridView.builder(
                padding: EdgeInsets.fromLTRB(
                    SpacingTokens.lg,
                    0,
                    SpacingTokens.lg,
                    playerBarInset(context,
                        miniPlayerVisible: ref.watch(hasMediaProvider))),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: SpacingTokens.lg,
                  crossAxisSpacing: SpacingTokens.lg,
                  childAspectRatio: 0.78,
                ),
                itemCount: albums.length,
                itemBuilder: (_, i) => AlbumGridTile(
                  album: albums[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlbumDetailPage(album: albums[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
