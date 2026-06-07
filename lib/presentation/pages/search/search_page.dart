import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/library/song_list_tile.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/player_bar_inset.dart';

/// Real-time full-text search across the library. Results are ranked by the
/// pure `searchSongs` matcher (title > artist > album > filename, prefix
/// bonus). Lyrics search layers in once the lyrics store exists (step 7).
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.lg,
              SpacingTokens.xl,
              SpacingTokens.lg,
              SpacingTokens.md,
            ),
            child: TextField(
              controller: _controller,
              autocorrect: false,
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                hintStyle:
                    AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
                prefixIcon: Icon(Icons.search, color: colors.onSurfaceFaint),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: colors.onSurfaceFaint),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      ),
                filled: true,
                fillColor: colors.surfaceElevated,
                border: const OutlineInputBorder(
                  borderRadius: RadiusTokens.brSm,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.md,
                  vertical: SpacingTokens.sm,
                ),
              ),
            ),
          ),
          Expanded(child: _results(context, l10n, query, results)),
        ],
      ),
    );
  }

  Widget _results(
    BuildContext context,
    AppLocalizations l10n,
    String query,
    AsyncValue<List<Song>> results,
  ) {
    if (query.trim().isEmpty) {
      return _centered(context, Icons.search, l10n.searchPrompt);
    }

    return results.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _centered(context, Icons.error_outline, l10n.errorGeneric),
      data: (songs) {
        if (songs.isEmpty) {
          return _centered(
            context,
            Icons.search_off,
            l10n.searchNoResults(query),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
              SpacingTokens.md,
              0,
              SpacingTokens.md,
              playerBarInset(context,
                  miniPlayerVisible: ref.watch(hasMediaProvider))),
          itemCount: songs.length,
          itemBuilder: (_, i) => SongListTile(
            song: songs[i],
            onTap: () =>
                ref.read(audioControllerProvider).playQueue(songs, startIndex: i),
            onMore: () => showSongActions(context, songs[i]),
          ),
        );
      },
    );
  }

  Widget _centered(BuildContext context, IconData icon, String message) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colors.onSurfaceFaint),
          const SizedBox(height: SpacingTokens.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
