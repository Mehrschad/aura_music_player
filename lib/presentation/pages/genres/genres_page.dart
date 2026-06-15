import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/genre.dart';
import '../../providers/async_value_x.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/section_header.dart';
import 'genre_detail_page.dart';

class GenresPage extends ConsumerWidget {
  const GenresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final genresAsync = ref.watch(genresProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l10n.tabGenres),
          Expanded(
            child: AsyncStateView<List<Genre>>(
              value: genresAsync.like,
              isEmpty: (g) => g.isEmpty,
              emptyMessage: l10n.libraryEmpty,
              emptyIcon: Icons.category_outlined,
              onRetry: () => ref.invalidate(songsProvider),
              data: (genres) => ListView.builder(
                padding: EdgeInsets.fromLTRB(
                    SpacingTokens.md,
                    0,
                    SpacingTokens.md,
                    playerBarInset(context,
                        miniPlayerVisible: ref.watch(hasMediaProvider))),
                itemCount: genres.length,
                itemBuilder: (_, i) {
                  final g = genres[i];
                  return ListTile(
                    leading: Icon(Icons.category_outlined,
                        color: colors.onSurfaceMuted),
                    title: Text(
                      g.isUnknown ? l10n.genreUnknown : g.name,
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurface),
                    ),
                    subtitle: Text(
                      l10n.songsCount(g.songCount),
                      style: AppTextTheme.caption
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GenreDetailPage(genre: g),
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
