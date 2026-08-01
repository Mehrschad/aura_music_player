import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/icon_sizes.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/stat_palette.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/play_event.dart';
import '../../../domain/models/song.dart';
import '../../../domain/stats/stats_logic.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/stats_providers.dart';
import '../../widgets/player_bar_inset.dart';
import '../../widgets/section_header.dart';
import 'listening_history_page.dart';

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

    final songs =
        ref.watch(effectiveSongsProvider).valueOrNull ?? const <Song>[];
    final titleById = {for (final s in songs) s.id: s.title};

    final overview = StatsLogic.overview(plays);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Soft top glow so the page reads warm and alive rather than a flat
          // black sheet — the colour bleeds down from behind the header.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      StatHues.teal.withOpacity(0.16),
                      StatHues.violet.withOpacity(0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: l10n.listeningStats,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.history, color: colors.onSurface),
                      tooltip: l10n.listeningHistory,
                      onPressed: () => openListeningHistory(context),
                    ),
                  ],
                ),
                _PeriodBar(
                  current: period,
                  onChanged: (p) =>
                      ref.read(statsPeriodProvider.notifier).state = p,
                ),
                Expanded(
                  child: plays.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bar_chart_rounded,
                                  size: IconSizes.huge,
                                  color: colors.onSurfaceFaint),
                              const SizedBox(height: SpacingTokens.md),
                              Text(l10n.noStatsYet,
                                  textAlign: TextAlign.center,
                                  style: AppTextTheme.body
                                      .copyWith(color: colors.onSurfaceMuted)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            SpacingTokens.lg,
                            SpacingTokens.sm,
                            SpacingTokens.lg,
                            playerBarInset(context,
                                miniPlayerVisible: ref.watch(hasMediaProvider)),
                          ),
                          children: [
                            _Overview(overview: overview),
                            const SizedBox(height: SpacingTokens.md),
                            _StreakCard(
                                streak:
                                    StatsLogic.currentStreak(history, now)),
                            const SizedBox(height: SpacingTokens.xl),
                            _Heading(l10n.listeningHeatmap, hue: StatHues.teal),
                            _Heatmap(
                                data: StatsLogic.heatmap(history, now: now)),
                            const SizedBox(height: SpacingTokens.xl),
                            _Heading(l10n.timeOfDay, hue: StatHues.teal),
                            _BarChart(
                                values: StatsLogic.timeOfDay(plays),
                                hue: StatHues.teal),
                            const SizedBox(height: SpacingTokens.xl),
                            _Heading(l10n.dayOfWeek, hue: StatHues.violet),
                            _BarChart(
                                values: StatsLogic.dayOfWeek(plays),
                                hue: StatHues.violet),
                            const SizedBox(height: SpacingTokens.xl),
                            _TopList(
                              title: l10n.topSongs,
                              hue: StatHues.teal,
                              entries: StatsLogic.topSongs(plays,
                                  labelFor: (id) => titleById[id] ?? id),
                            ),
                            _TopList(
                                title: l10n.topArtists,
                                hue: StatHues.violet,
                                entries: StatsLogic.topArtists(plays)),
                            _TopList(
                                title: l10n.topAlbums,
                                hue: StatHues.amber,
                                entries: StatsLogic.topAlbums(plays)),
                            _TopList(
                                title: l10n.topGenres,
                                hue: StatHues.coral,
                                entries: StatsLogic.topGenres(plays)),
                            const SizedBox(height: SpacingTokens.sm),
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
        ],
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
                selectedColor: StatHues.teal.withOpacity(0.20),
                labelStyle: AppTextTheme.caption.copyWith(
                  color: p == current ? StatHues.teal : colors.onSurfaceMuted,
                  fontWeight: p == current ? FontWeight.w700 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: p == current
                      ? StatHues.teal.withOpacity(0.4)
                      : Colors.transparent,
                ),
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
        _StatTile(
            count: overview.totalPlays,
            label: l10n.statPlays,
            color: StatHues.teal),
        _StatTile(
            value: overview.totalListening.humanized,
            label: l10n.statListening,
            color: StatHues.violet),
        _StatTile(
            count: overview.uniqueTracks,
            label: l10n.statTracks,
            color: StatHues.amber),
        _StatTile(
            count: overview.uniqueArtists,
            label: l10n.statArtists,
            color: StatHues.coral),
        _StatTile(
            count: overview.uniqueAlbums,
            label: l10n.statAlbums,
            color: StatHues.blue),
      ],
    );
  }
}

/// A single overview tile: a colour-tinted panel whose number counts up on
/// first paint, with a matching accent glyph bar. Pass [count] for an animated
/// integer, or [value] for a pre-formatted string (e.g. a duration).
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.color,
    this.count,
    this.value,
  });

  final String label;
  final Color color;
  final int? count;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 106,
      padding: const EdgeInsets.symmetric(
          vertical: SpacingTokens.md, horizontal: SpacingTokens.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.20), color.withOpacity(0.06)],
        ),
        borderRadius: RadiusTokens.brMd,
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (count != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: count!.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                '${v.round()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.title.copyWith(
                    color: color, fontWeight: FontWeight.w800),
              ),
            )
          else
            Text(value ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.title
                    .copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted)),
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
        gradient: LinearGradient(
          colors: [
            StatHues.coral.withOpacity(0.22),
            StatHues.amber.withOpacity(0.10),
          ],
        ),
        borderRadius: RadiusTokens.brMd,
        border: Border.all(color: StatHues.coral.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: StatHues.coral, size: 28),
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
  const _Heading(this.text, {required this.hue});
  final String text;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            margin: const EdgeInsets.only(right: SpacingTokens.sm),
            decoration: BoxDecoration(
              color: hue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(text,
              style: AppTextTheme.title.copyWith(
                  color: colors.onSurface, fontWeight: FontWeight.w700)),
        ],
      ),
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
        // Grow the fill in as the page settles.
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, t, _) => CustomPaint(
            size: Size(c.maxWidth, 7 * 13.0),
            painter: _HeatmapPainter(
              data: data,
              base: colors.surfaceElevated,
              accent: StatHues.teal,
              progress: t,
            ),
          ),
        );
      }),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.data,
    required this.base,
    required this.accent,
    required this.progress,
  });
  final Map<DateTime, int> data;
  final Color base;
  final Color accent;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final days = data.keys.toList()..sort();
    final maxMin = data.values.fold<int>(1, math.max);

    const cell = 11.0;
    const gap = 2.0;
    final today = days.last;
    final paint = Paint();
    for (final day in days) {
      final daysAgo = today.difference(day).inDays;
      final col = (days.length - 1 - daysAgo) ~/ 7;
      final row = day.weekday - 1; // Mon=0 … Sun=6
      final mins = data[day] ?? 0;
      final t =
          mins == 0 ? 0.0 : (0.18 + 0.82 * (mins / maxMin)).clamp(0.0, 1.0);
      // Warm the busiest cells toward amber so intensity reads as heat.
      final full = mins == 0
          ? base
          : Color.lerp(Color.lerp(base, accent, t)!, StatHues.amber, t * 0.35)!;
      paint.color = mins == 0 ? base : Color.lerp(base, full, progress)!;
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
  bool shouldRepaint(_HeatmapPainter o) =>
      o.data != data || o.accent != accent || o.progress != progress;
}

// ── Bar chart (time of day / day of week) ────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({required this.values, required this.hue});
  final List<int> values;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxV = values.fold<int>(1, math.max);
    // A single grow-in animation drives every bar from the baseline.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: 84,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final v in values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: 4 + 76 * (v / maxV) * t,
                    decoration: BoxDecoration(
                      gradient: v == 0
                          ? null
                          : LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [hue, hue.withOpacity(0.55)],
                            ),
                      color: v == 0 ? colors.surfaceElevated : null,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Top lists ────────────────────────────────────────────────────────────────

class _TopList extends StatelessWidget {
  const _TopList({required this.title, required this.entries, required this.hue});
  final String title;
  final List<StatEntry> entries;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final maxPlays = entries.fold<int>(1, (m, e) => math.max(m, e.plays));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(title, hue: hue),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                // Colour-tinted rank badge.
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hue.withOpacity(i == 0 ? 0.30 : 0.14),
                    borderRadius: RadiusTokens.brSm,
                  ),
                  child: Text('${i + 1}',
                      style: AppTextTheme.caption.copyWith(
                        color: hue,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entries[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextTheme.body
                              .copyWith(color: colors.onSurface)),
                      const SizedBox(height: 5),
                      // A proportion bar (share of the leader) grows in.
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: 0, end: entries[i].plays / maxPlays),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, frac, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 4,
                            backgroundColor: colors.surfaceElevated,
                            valueColor: AlwaysStoppedAnimation<Color>(hue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SpacingTokens.sm),
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
        _Heading(l10n.forgottenGems, hue: StatHues.blue),
        for (final s in gems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${s.title} · ${s.artist}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
          ),
      ],
    );
  }
}
