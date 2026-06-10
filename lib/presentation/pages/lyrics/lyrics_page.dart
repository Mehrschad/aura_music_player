import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/constants/motion_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/lyrics.dart';
import '../../providers/async_value_x.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/lyrics_view/karaoke_line.dart';
import 'sync_editor_page.dart';

Future<void> openLyrics(BuildContext context) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: context.motion(MotionTokens.screen),
    reverseTransitionDuration: context.motion(MotionTokens.screen),
    pageBuilder: (_, __, ___) => const LyricsPage(),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: MotionTokens.standard),
      child: child,
    ),
  ));
}

/// Lyric font sizes (current line / secondary lines / translation), keyed by
/// the user's [LyricsFontSize] preference. Feature-local layout config rather
/// than the global type scale, since lyric sizing is user-adjustable.
class _LyricMetrics {
  const _LyricMetrics._();
  static const Map<LyricsFontSize, double> current = {
    LyricsFontSize.small: 18,
    LyricsFontSize.medium: 22,
    LyricsFontSize.large: 28,
  };
  static const Map<LyricsFontSize, double> secondary = {
    LyricsFontSize.small: 14,
    LyricsFontSize.medium: 16,
    LyricsFontSize.large: 19,
  };
  static const Map<LyricsFontSize, double> translation = {
    LyricsFontSize.small: 12,
    LyricsFontSize.medium: 13,
    LyricsFontSize.large: 15,
  };
}

class LyricsPage extends ConsumerStatefulWidget {
  const LyricsPage({super.key});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  final _scrollController = ScrollController();
  List<GlobalKey> _keys = const [];
  int _keyCount = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureKeys(int count) {
    if (_keyCount == count) return;
    _keyCount = count;
    _keys = List.generate(count, (_) => GlobalKey());
  }

  void _scrollTo(int index) {
    if (index < 0 || index >= _keys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.38, // current line sits ~38% from the top
        duration: MotionTokens.screen,
        curve: MotionTokens.emphasized,
      );
    });
  }

  TextDirection _directionFor(String text) =>
      intl.Bidi.detectRtlDirectionality(text)
          ? TextDirection.rtl
          : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final song = ref.watch(currentSongProvider);
    final lyricsAsync = ref.watch(currentLyricsProvider);
    final fontSize = ref.watch(lyricsFontSizeProvider);
    final dual = ref.watch(dualLanguageProvider);
    final accent = SeedPalette.accent(song?.artworkSeed ?? 'lyrics');

    // Auto-scroll on line change.
    ref.listen<int>(currentLyricLineProvider, (_, next) => _scrollTo(next));

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Blurred album-art background + dark overlay.
          if (song != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: AuraArtwork(
                    seed: song.artworkSeed,
                    size: MediaQuery.sizeOf(context).width,
                    hasArtwork: song.hasArtwork,
                  ),
                ),
              ),
            ),
          Positioned.fill(child: ColoredBox(color: colors.background.withOpacity(0.48))),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: l10n.lyrics,
                  hasTranslations:
                      lyricsAsync.valueOrNull?.hasTranslations ?? false,
                  dual: dual,
                  fontSize: fontSize,
                  onToggleDual: () => ref
                      .read(dualLanguageProvider.notifier)
                      .update((v) => !v),
                  onCycleFontSize: () => ref
                      .read(lyricsFontSizeProvider.notifier)
                      .update(_nextFontSize),
                  onOpenSync: () => openSyncEditor(context),
                ),
                Expanded(
                  child: AsyncStateView<Lyrics?>(
                    value: lyricsAsync.like,
                    isEmpty: (l) => l == null || l.isEmpty,
                    emptyMessage: l10n.lyricsNone,
                    emptyIcon: Icons.lyrics_outlined,
                    data: (lyrics) => _LyricsBody(
                      lyrics: lyrics!,
                      controller: _scrollController,
                      keys: () {
                        _ensureKeys(lyrics.lines.length);
                        return _keys;
                      }(),
                      fontSize: fontSize,
                      dual: dual,
                      accent: accent,
                      directionFor: _directionFor,
                    ),
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

LyricsFontSize _nextFontSize(LyricsFontSize s) => switch (s) {
      LyricsFontSize.small => LyricsFontSize.medium,
      LyricsFontSize.medium => LyricsFontSize.large,
      LyricsFontSize.large => LyricsFontSize.small,
    };

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.hasTranslations,
    required this.dual,
    required this.fontSize,
    required this.onToggleDual,
    required this.onCycleFontSize,
    required this.onOpenSync,
  });

  final String title;
  final bool hasTranslations;
  final bool dual;
  final LyricsFontSize fontSize;
  final VoidCallback onToggleDual;
  final VoidCallback onCycleFontSize;
  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.keyboard_arrow_down, color: colors.onSurface),
          iconSize: 28,
        ),
        Expanded(
          child: Text(title,
              textAlign: TextAlign.center,
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted)),
        ),
        if (hasTranslations)
          IconButton(
            tooltip: dual ? l10n.lyricsDual : l10n.lyricsSingle,
            onPressed: onToggleDual,
            icon: Icon(Icons.translate,
                color: dual ? colors.onSurface : colors.onSurfaceFaint),
          ),
        IconButton(
          tooltip: l10n.lyricsFontSize,
          onPressed: onCycleFontSize,
          icon: Icon(Icons.format_size, color: colors.onSurfaceMuted),
        ),
        IconButton(
          tooltip: l10n.syncTitle,
          onPressed: onOpenSync,
          icon: Icon(Icons.edit_note, color: colors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _LyricsBody extends ConsumerWidget {
  const _LyricsBody({
    required this.lyrics,
    required this.controller,
    required this.keys,
    required this.fontSize,
    required this.dual,
    required this.accent,
    required this.directionFor,
  });

  final Lyrics lyrics;
  final ScrollController controller;
  final List<GlobalKey> keys;
  final LyricsFontSize fontSize;
  final bool dual;
  final Color accent;
  final TextDirection Function(String) directionFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = lyrics.synced ? ref.watch(currentLyricLineProvider) : -1;
    final controllerRef = ref.read(audioControllerProvider);

    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.xl,
        vertical: MediaQuery.sizeOf(context).height * 0.32,
      ),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, i) {
        final line = lyrics.lines[i];
        final relation = !lyrics.synced
            ? _Relation.neutral
            : i == current
                ? _Relation.current
                : i < current
                    ? _Relation.past
                    : _Relation.future;
        final lineEnd = i + 1 < lyrics.lines.length
            ? lyrics.lines[i + 1].time
            : line.time + const Duration(seconds: 4);

        return Padding(
          key: keys.length == lyrics.lines.length ? keys[i] : null,
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
          child: _LyricRow(
            line: line,
            relation: relation,
            fontSize: fontSize,
            dual: dual,
            accent: accent,
            lineEnd: lineEnd,
            direction: directionFor(line.text),
            onTap: lyrics.synced ? () => controllerRef.seek(line.time) : null,
          ),
        );
      },
    );
  }
}

enum _Relation { current, past, future, neutral }

class _LyricRow extends StatelessWidget {
  const _LyricRow({
    required this.line,
    required this.relation,
    required this.fontSize,
    required this.dual,
    required this.accent,
    required this.lineEnd,
    required this.direction,
    required this.onTap,
  });

  final LyricsLine line;
  final _Relation relation;
  final LyricsFontSize fontSize;
  final bool dual;
  final Color accent;
  final Duration lineEnd;
  final TextDirection direction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCurrent = relation == _Relation.current;
    final size = (isCurrent
        ? _LyricMetrics.current
        : _LyricMetrics.secondary)[fontSize]!;

    final color = switch (relation) {
      _Relation.current => accent,
      _Relation.past => colors.onSurfaceFaint,
      _Relation.future => colors.onSurfaceMuted,
      _Relation.neutral => colors.onSurface,
    };

    final style = AppTextTheme.body.copyWith(
      fontSize: size,
      height: 1.3,
      fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
      color: color,
    );

    final Widget primary;
    if (isCurrent && line.hasWordTimings) {
      primary = _CurrentKaraoke(
        words: line.words,
        lineEnd: lineEnd,
        style: style,
        accent: accent,
        base: colors.onSurfaceFaint,
        direction: direction,
      );
    } else {
      primary = Text(
        line.text,
        textDirection: direction,
        textAlign: TextAlign.center,
        style: style,
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        primary,
        if (dual && line.translation != null) ...[
          const SizedBox(height: 2),
          Text(
            line.translation!,
            textDirection: directionForText(line.translation!),
            textAlign: TextAlign.center,
            style: AppTextTheme.caption.copyWith(
              fontSize: _LyricMetrics.translation[fontSize]!,
              color: colors.onSurfaceFaint,
            ),
          ),
        ],
      ],
    );

    // Wrap the active line in a subtle glass capsule.
    final Widget inner = isCurrent
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withOpacity(0.20), width: 1),
            ),
            child: content,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: content,
          );

    return GestureDetector(
      onTap: onTap,
      child: Center(child: inner),
    );
  }

  static TextDirection directionForText(String text) =>
      intl.Bidi.detectRtlDirectionality(text)
          ? TextDirection.rtl
          : TextDirection.ltr;
}

/// The active line's karaoke fill — watches [positionProvider] so only this one
/// line repaints per tick.
class _CurrentKaraoke extends ConsumerWidget {
  const _CurrentKaraoke({
    required this.words,
    required this.lineEnd,
    required this.style,
    required this.accent,
    required this.base,
    required this.direction,
  });

  final List<LyricWord> words;
  final Duration lineEnd;
  final TextStyle style;
  final Color accent;
  final Color base;
  final TextDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    return KaraokeLine(
      words: words,
      lineEnd: lineEnd,
      position: position,
      style: style,
      accent: accent,
      base: base,
      textDirection: direction,
    );
  }
}
