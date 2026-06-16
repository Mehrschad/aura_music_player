import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/constants/icon_sizes.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/play_event.dart';
import '../../../domain/models/song.dart';
import '../../../domain/stats/history_timeline.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/stats_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/player_bar_inset.dart';

void openListeningHistory(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ListeningHistoryPage()),
  );
}

/// A raw chronological feed of every play/skip, grouped by calendar day.
class ListeningHistoryPage extends ConsumerWidget {
  const ListeningHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final days = ref.watch(listeningHistoryProvider);
    final songs = ref.watch(effectiveSongsProvider).valueOrNull ?? const <Song>[];
    final songById = {for (final s in songs) s.id: s};
    final localeName = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(
          l10n.listeningHistory,
          style: AppTextTheme.title.copyWith(color: colors.onSurface),
        ),
      ),
      body: days.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: IconSizes.huge, color: colors.onSurfaceFaint),
                  const SizedBox(height: SpacingTokens.md),
                  Text(
                    l10n.noHistoryYet,
                    textAlign: TextAlign.center,
                    style: AppTextTheme.body
                        .copyWith(color: colors.onSurfaceMuted),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  SpacingTokens.lg,
                  0,
                  SpacingTokens.lg,
                  playerBarInset(context,
                      miniPlayerVisible: ref.watch(hasMediaProvider))),
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DayHeader(
                      label: _dayLabel(
                        l10n,
                        localeName,
                        day.date,
                        today: today,
                        yesterday: yesterday,
                      ),
                    ),
                    for (final event in day.events)
                      _HistoryRow(
                        event: event,
                        song: songById[event.songId],
                        localeName: localeName,
                      ),
                  ],
                );
              },
            ),
    );
  }

  // Relative label for a day header: today / yesterday / formatted date.
  String _dayLabel(
    AppLocalizations l10n,
    String localeName,
    DateTime date, {
    required DateTime today,
    required DateTime yesterday,
  }) {
    if (date == today) return l10n.historyToday;
    if (date == yesterday) return l10n.historyYesterday;
    return intl.DateFormat.yMMMMd(localeName).format(date);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(
          top: SpacingTokens.lg, bottom: SpacingTokens.sm),
      child: Text(
        label,
        style: AppTextTheme.title
            .copyWith(color: colors.onSurface, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.event,
    required this.song,
    required this.localeName,
  });

  final PlayEvent event;
  final Song? song;
  final String localeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final isCurrent =
        ref.watch(currentSongProvider.select((s) => s?.id == event.songId));
    final time = intl.DateFormat.Hm(localeName).format(event.at);

    return InkWell(
      // History is denormalised; tapping a deleted song is a no-op.
      onTap: song == null
          ? null
          : () => ref.read(audioControllerProvider).playQueue([song!]),
      borderRadius: RadiusTokens.brMd,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: RadiusTokens.brMd,
          color: isCurrent
              ? colors.accent.withOpacity(0.07)
              : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.xs,
          vertical: SpacingTokens.sm,
        ),
        child: Row(
          children: [
            AuraArtwork(
              seed: song?.artworkSeed ?? event.album,
              size: 44,
              hasArtwork: song?.hasArtwork ?? false,
              artworkId: song != null ? int.tryParse(song!.id) : null,
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.body.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.caption
                        .copyWith(color: colors.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SpacingTokens.sm),
            if (!event.completed) ...[
              _SkippedChip(label: l10n.historySkipped),
              const SizedBox(width: SpacingTokens.sm),
            ],
            Text(
              time,
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// A muted pill marking an event that was skipped rather than played through.
class _SkippedChip extends StatelessWidget {
  const _SkippedChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.sm, vertical: SpacingTokens.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: RadiusTokens.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.skip_next_rounded, size: 14, color: colors.onSurfaceFaint),
          const SizedBox(width: SpacingTokens.xxs),
          Text(
            label,
            style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
          ),
        ],
      ),
    );
  }
}
