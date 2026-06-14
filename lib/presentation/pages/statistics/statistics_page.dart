import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/play_event.dart';
import '../../../domain/models/song.dart';
import '../../../domain/stats/stats_logic.dart';
import '../../providers/library_providers.dart';
import '../../providers/stats_providers.dart';
import '../../widgets/section_header.dart';

void openStatistics(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const StatisticsPage()),
  );
}

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final period = ref.watch(statsPeriodProvider);
    final plays = ref.watch(periodPlaysProvider);
    final history = ref.watch(playHistoryProvider);
    final now = DateTime.now();

    final songs = ref.watch(effectiveSongsProvider).valueOrNull ?? const <Song>[];
    final titleById = {for (final s in songs) s.id: s.title};

    final overview = StatsLogic.overview(plays);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l10n.listeningStats),
            _PeriodBar(
              current: period,
              onChanged: (p) =>
                  ref.read(statsPeriodProvider.notifier).state = p,
            ),
            Expanded(
              child: plays.isEmpty
                  ? Center(
                      child: Text(l10n.noStatsYet,
                          style: AppTextTheme.body
                              .copyWith(color: colors.onSurfaceMuted)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, 0,
                          SpacingTokens.lg, SpacingTokens.xxl),
                      children: [
                        _Overview(overview: overview),
                        const SizedBox(height: SpacingTokens.md),
                        _StreakCard(
                            streak: StatsLogic.currentStreak(history, now)),
                        const SizedBox(height: SpacingTokens.lg),
                        _Heading(l10n.listeningHeatmap),
                        _Heatmap(
                            data: StatsLogic.heatmap(history, now: now)),
                        const SizedBox(height: SpacingTokens.lg),
                        _Heading(l10n.timeOfDay),
                        _BarChart(values: StatsLogic.timeOfDay(plays)),
                        const SizedBox(height: SpacingTokens.lg),
                        _TopList(
                          title: l10n.topSongs,
                          entries: StatsLogic.topSongs(plays,
                              labelFor: (id) => titleById[id] ?? id),
                        ),
                        _TopList(
                            title: l10n.topArtists,
                            entries: StatsLogic.topArtists(plays)),
                        _TopList(
                            title: l10n.topAlbums,
                            entries: StatsLogic.topAlbums(plays)),
                        const SizedBox(height: SpacingTokens.lg),
                        _ForgottenGems(
                          gems: StatsLogic.forgottenGems(songs, now: now)
                              .take(10)
                              .toList(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Period selector ──────────────────────────────────────────────────────────

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.current, required this.onChanged});
  final StatsPeriod current;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    String label(StatsPeriod p) => switch (p) {
          StatsPeriod.today => l10n.periodToday,
          StatsPeriod.week => l10n.periodWeek,
          StatsPeriod.month => l10n.periodMonth,
          StatsPeriod.year => l10n.periodYear,
          StatsPeriod.allTime => l10n.periodAllTime,
        };
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
        children: [
          for (final p in StatsPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: SpacingTokens.xs),
              child: ChoiceChip(
                label: Text(label(p)),
                selected: p == current,
                onSelected: (_) => onChanged(p),
                showCheckmark: false,
                backgroundColor: colors.surfaceElevated,
                selectedColor: colors.accent.withOpacity(0.18),
                labelStyle: AppTextTheme.caption.copyWith(
                  color: p == current ? colors.accent : colors.onSurfaceMuted,
                  fontWeight: p == current ? FontWeight.w700 : FontWeight.w400,
                ),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Overview cards ───────────────────────────────────────────────────────────

class _Overview extends StatelessWidget {
  const _Overview({required this.overview});
  final StatsOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: SpacingTokens.sm,
      runSpacing: SpacingTokens.sm,
      children: [
        _StatTile(value: '${overview.totalPlays}', label: l10n.statPlays),
        _StatTile(
            value: overview.totalListening.humanized,
            label: l10n.statListening),
        _StatTile(value: '${overview.uniqueTracks}', label: l10n.statTracks),
        _StatTile(value: '${overview.uniqueArtists}', label: l10n.statArtists),
        _StatTile(value: '${overview.uniqueAlbums}', label: l10n.statAlbums),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(
          vertical: SpacingTokens.md, horizontal: SpacingTokens.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: RadiusTokens.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextTheme.title.copyWith(
                  color: colors.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextTheme.caption
                  .copyWith(color: colors.onSurfaceFaint)),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: RadiusTokens.brMd,
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: colors.accent, size: 28),
          const SizedBox(width: SpacingTokens.sm),
          Text(l10n.streakDays(streak),
              style: AppTextTheme.body.copyWith(
                  color: colors.onSurface, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Text(text,
          style: AppTextTheme.title.copyWith(
              color: colors.onSurface, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Heatmap ──────────────────────────────────────────────────────────────────

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.data});
  final Map<DateTime, int> data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 7 * 13.0,
      child: LayoutBuilder(builder: (context, c) {
        return CustomPaint(
          size: Size(c.maxWidth, 7 * 13.0),
          painter: _HeatmapPainter(
            data: data,
            base: colors.surfaceElevated,
            accent: colors.accent,
          ),
        );
      }),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter(
      {required this.data, required this.base, required this.accent});
  final Map<DateTime, int> data;
  final Color base;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final days = data.keys.toList()..sort();
    final maxMin = data.values.fold<int>(1, math.max);

    const cell = 11.0;
    const gap = 2.0;
    // Column 0 = oldest week. Align so the last day sits bottom-right.
    final today = days.last;
    final paint = Paint();
    for (final day in days) {
      final daysAgo = today.difference(day).inDays;
      final col = (days.length - 1 - daysAgo) ~/ 7;
      final row = (day.weekday - 1); // Mon=0 … Sun=6
      final mins = data[day] ?? 0;
      final t = mins == 0 ? 0.0 : (0.18 + 0.82 * (mins / maxMin)).clamp(0.0, 1.0);
      paint.color = mins == 0 ? base : Color.lerp(base, accent, t)!;
      final x = col * (cell + gap);
      final y = row * (cell + gap);
      if (x > size.width) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, cell, cell), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter o) => o.data != data || o.accent != accent;
}

// ── Bar chart (time of day) ──────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({required this.values});
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxV = values.fold<int>(1, math.max);
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  height: 4 + 72 * (v / maxV),
                  decoration: BoxDecoration(
                    color: v == 0
                        ? colors.surfaceElevated
                        : colors.accent.withOpacity(0.7),
                    borderRadius: RadiusTokens.brXs,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Top lists ────────────────────────────────────────────────────────────────

class _TopList extends StatelessWidget {
  const _TopList({required this.title, required this.entries});
  final String title;
  final List<StatEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(title),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}',
                      style: AppTextTheme.caption
                          .copyWith(color: colors.onSurfaceFaint)),
                ),
                Expanded(
                  child: Text(entries[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurface)),
                ),
                Text(l10n.playsCount(entries[i].plays),
                    style: AppTextTheme.caption
                        .copyWith(color: colors.onSurfaceMuted)),
              ],
            ),
          ),
        const SizedBox(height: SpacingTokens.md),
      ],
    );
  }
}

class _ForgottenGems extends StatelessWidget {
  const _ForgottenGems({required this.gems});
  final List<Song> gems;

  @override
  Widget build(BuildContext context) {
    if (gems.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(l10n.forgottenGems),
        for (final s in gems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${s.title} · ${s.artist}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
          ),
      ],
    );
  }
}
