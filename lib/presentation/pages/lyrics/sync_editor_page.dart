import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/lyrics/sync_draft.dart';
import '../../../domain/models/lyrics.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/player/play_pause_button.dart';
import '../../widgets/waveform/waveform_scrubber.dart';

Future<void> openSyncEditor(BuildContext context) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: context.motion(MotionTokens.screen),
    pageBuilder: (_, __, ___) => const SyncEditorPage(),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: MotionTokens.standard),
      child: child,
    ),
  ));
}

enum _Mode { tap, tune }

class SyncEditorPage extends ConsumerStatefulWidget {
  const SyncEditorPage({super.key});

  @override
  ConsumerState<SyncEditorPage> createState() => _SyncEditorPageState();
}

class _SyncEditorPageState extends ConsumerState<SyncEditorPage> {
  SyncDraft? _draft;
  _Mode _mode = _Mode.tap;
  final _pasteController = TextEditingController();
  bool _seeded = false;

  // 100 ms both for a single line and for the whole sheet: 500 ms per line was
  // far coarser than the error you are actually chasing when fine-tuning.
  static const _shiftLine = Duration(milliseconds: 100);
  static const _shiftAll = Duration(milliseconds: 100);

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  void _seedFromLyrics(Lyrics? lyrics) {
    if (_seeded || lyrics == null || lyrics.isEmpty) return;
    _seeded = true;
    _draft = SyncDraft.fromLyrics(lyrics);
  }

  void _stampNow() {
    final draft = _draft;
    if (draft == null || draft.currentEntry == null) return;
    HapticFeedback.selectionClick();
    setState(() => _draft = draft.stamp(ref.read(audioControllerProvider).position));
  }

  Future<void> _editTimestamp(int index) async {
    final entry = _draft!.entries[index];
    final controller = TextEditingController(
        text: entry.time == null ? '' : formatLrcTimestamp(entry.time!));
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: const RoundedRectangleBorder(borderRadius: RadiusTokens.brLg),
        title: Text(l10n.editTimestamp,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTextTheme.body.copyWith(color: colors.onSurface),
          decoration: const InputDecoration(hintText: 'mm:ss.xx'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final parsed = parseLrcTimestamp(result);
    if (parsed != null) setState(() => _draft = _draft!.setTime(index, parsed));
  }

  /// Stamps the line the user is editing with the live playback position —
  /// the fast way to fix one line without re-running the whole tap pass.
  void _stampAt(int index) {
    HapticFeedback.selectionClick();
    setState(() => _draft =
        _draft!.setTime(index, ref.read(audioControllerProvider).position));
  }

  Future<void> _save() async {
    final draft = _draft;
    final song = ref.read(currentSongProvider);
    if (draft == null || song == null) return;

    // Saving drops lines that were never stamped, because LRC has nowhere to
    // put them. That used to happen silently and lose words, so say it plainly
    // and let the user go back and finish.
    final missing = draft.entries.length - draft.stampedCount;
    if (missing > 0) {
      final colors = context.colors;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surfaceElevated,
          shape: const RoundedRectangleBorder(borderRadius: RadiusTokens.brLg),
          title: Text('Save an unfinished sync?',
              style: AppTextTheme.title.copyWith(color: colors.onSurface)),
          content: Text(
            '$missing of ${draft.entries.length} lines have no timestamp yet. '
            'Saving now keeps the ${draft.stampedCount} timed lines and drops '
            'the rest.',
            style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final lrc = draft.toLrc();
    final lyrics = parseLrc(lrc);
    ref.read(lyricsOverridesProvider.notifier).save(song.id, lyrics);
    await Clipboard.setData(ClipboardData(text: lrc));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final label = AppLocalizations.of(context).syncSaved;
    Navigator.of(context).maybePop();
    messenger.showSnackBar(
        SnackBar(content: Text('$label · copied as LRC')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    // unwrapPrevious: never seed the editor with a previous track's lyrics.
    _seedFromLyrics(
        ref.watch(currentLyricsProvider).unwrapPrevious().valueOrNull);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(l10n.syncTitle,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        actions: [
          if (_draft != null)
            TextButton(
              onPressed: _draft!.hasStarted ? _save : null,
              child: Text(l10n.save),
            ),
        ],
      ),
      body: _draft == null ? _buildPaste(context) : _buildEditor(context),
    );
  }

  Widget _buildPaste(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _pasteController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: l10n.syncPasteHint,
                hintStyle:
                    AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
                filled: true,
                fillColor: colors.surfaceElevated,
                border: const OutlineInputBorder(
                    borderRadius: RadiusTokens.brSm,
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          FilledButton(
            onPressed: () {
              final draft =
                  SyncDraft.fromTexts(_pasteController.text.split('\n'));
              if (draft.entries.isEmpty) return;
              setState(() => _draft = draft);
            },
            style: FilledButton.styleFrom(
                backgroundColor: colors.onSurface,
                foregroundColor: colors.background),
            child: Text(l10n.syncStart),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = _draft!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(SpacingTokens.md, SpacingTokens.md,
              SpacingTokens.md, SpacingTokens.xs),
          child: SegmentedButton<_Mode>(
            segments: [
              ButtonSegment(value: _Mode.tap, label: Text(l10n.syncModeTap)),
              ButtonSegment(value: _Mode.tune, label: Text(l10n.syncModeTune)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        _ProgressStrip(
          stamped: draft.stampedCount,
          total: draft.entries.length,
        ),
        Expanded(
          child: _mode == _Mode.tap
              ? _TapPhase(
                  draft: draft,
                  onTap: _stampNow,
                  onUndo: () => setState(() => _draft = draft.undo()),
                )
              : _TunePhase(
                  draft: draft,
                  shiftLine: _shiftLine,
                  shiftAll: _shiftAll,
                  onShiftLine: (i, d) =>
                      setState(() => _draft = draft.shiftLine(i, d)),
                  onShiftAll: (d) =>
                      setState(() => _draft = draft.shiftAll(d)),
                  onEdit: _editTimestamp,
                  onStampAt: _stampAt,
                  onClear: (i) => setState(() => _draft = draft.clearTime(i)),
                ),
        ),
        // Transport lives outside the phases: you need to scrub and pause just
        // as much while fine-tuning as while tapping, and switching tabs to
        // reach the play button was the worst of the old flow.
        const _TransportBar(),
      ],
    );
  }
}

/// Thin "n of m stamped" bar. Tapping through a long lyric with no sense of
/// progress was disorienting; this is always visible in both modes.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.stamped, required this.total});

  final int stamped;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = total == 0 ? 0.0 : stamped / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg, 0, SpacingTokens.lg, SpacingTokens.sm),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: RadiusTokens.brPill,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: colors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          Text('$stamped / $total',
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint)),
        ],
      ),
    );
  }
}

/// Playback transport shared by both editor modes: elapsed time, ±5s jog,
/// play/pause, restart, and the waveform to scrub on.
class _TransportBar extends ConsumerWidget {
  const _TransportBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final song = ref.watch(currentSongProvider);
    final playing =
        ref.watch(playbackStateProvider).valueOrNull?.playing ?? false;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final controller = ref.read(audioControllerProvider);
    final accent = SeedPalette.accent(song?.artworkSeed ?? 'sync');

    void jog(Duration delta) {
      final next = position + delta;
      controller.seek(next < Duration.zero ? Duration.zero : next);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, SpacingTokens.sm,
          SpacingTokens.lg, SpacingTokens.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song != null)
            WaveformScrubber(
              duration: song.duration,
              accent: accent,
              seed: song.artworkSeed,
              isPlaying: playing,
            ),
          const SizedBox(height: SpacingTokens.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: l10n.syncRestart,
                onPressed: () => controller.seek(Duration.zero),
                icon: Icon(Icons.replay, color: colors.onSurfaceMuted),
              ),
              IconButton(
                tooltip: 'Back 5s',
                onPressed: () => jog(const Duration(seconds: -5)),
                icon: Icon(Icons.replay_5, color: colors.onSurfaceMuted),
              ),
              PlayPauseButton(
                playing: playing,
                onTap: controller.togglePlayPause,
                size: 52,
              ),
              IconButton(
                tooltip: 'Forward 5s',
                onPressed: () => jog(const Duration(seconds: 5)),
                icon: Icon(Icons.forward_5, color: colors.onSurfaceMuted),
              ),
              // Live position: the number you're stamping against.
              SizedBox(
                width: 64,
                child: Text(
                  formatLrcTimestamp(position),
                  textAlign: TextAlign.center,
                  style: AppTextTheme.caption
                      .copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Tap mode: play the track and tap once per line.
///
/// Shows a real window of surrounding lines rather than a single line in
/// isolation, so you can see what is coming and confirm what you just stamped.
class _TapPhase extends ConsumerWidget {
  const _TapPhase({
    required this.draft,
    required this.onTap,
    required this.onUndo,
  });

  final SyncDraft draft;
  final VoidCallback onTap;
  final VoidCallback onUndo;

  static const int _lookAround = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final song = ref.watch(currentSongProvider);
    final accent = SeedPalette.accent(song?.artworkSeed ?? 'sync');
    final cursor = draft.cursor;
    final done = cursor >= draft.entries.length;

    Widget lineAt(int i) {
      if (i < 0 || i >= draft.entries.length) {
        return const SizedBox(height: 22);
      }
      final entry = draft.entries[i];
      final isNext = i == cursor;
      final stamped = entry.time != null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timestamps stay visible behind the current line so you can see
            // the pass building up as you tap.
            SizedBox(
              width: 56,
              child: Text(
                stamped ? formatLrcTimestamp(entry.time!) : '',
                textAlign: TextAlign.end,
                style: AppTextTheme.caption
                    .copyWith(color: colors.onSurfaceFaint, fontSize: 11),
              ),
            ),
            const SizedBox(width: SpacingTokens.md),
            Flexible(
              child: Text(
                entry.text,
                textAlign: TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: isNext
                    ? AppTextTheme.heroTitle
                        .copyWith(color: accent, fontSize: 24)
                    : AppTextTheme.body.copyWith(
                        color: stamped
                            ? colors.onSurfaceFaint
                            : colors.onSurfaceMuted,
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: done ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              done ? 'Every line is stamped' : l10n.syncTapHint,
              textAlign: TextAlign.center,
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
            ),
            const SizedBox(height: SpacingTokens.lg),
            for (var d = -_lookAround; d <= _lookAround; d++)
              lineAt(cursor + d),
            const SizedBox(height: SpacingTokens.lg),
            TextButton.icon(
              onPressed: draft.hasStarted ? onUndo : null,
              icon: const Icon(Icons.undo, size: 18),
              label: Text(l10n.syncUndo),
              style: TextButton.styleFrom(
                  foregroundColor: colors.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tune mode: the full line list, following playback, with per-line controls.
class _TunePhase extends ConsumerStatefulWidget {
  const _TunePhase({
    required this.draft,
    required this.shiftLine,
    required this.shiftAll,
    required this.onShiftLine,
    required this.onShiftAll,
    required this.onEdit,
    required this.onStampAt,
    required this.onClear,
  });

  final SyncDraft draft;
  final Duration shiftLine;
  final Duration shiftAll;
  final void Function(int index, Duration delta) onShiftLine;
  final void Function(Duration delta) onShiftAll;
  final void Function(int index) onEdit;
  final void Function(int index) onStampAt;
  final void Function(int index) onClear;

  @override
  ConsumerState<_TunePhase> createState() => _TunePhaseState();
}

class _TunePhaseState extends ConsumerState<_TunePhase> {
  final _scrollController = ScrollController();
  int _followed = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Keeps the playing line on screen. Only fires when the active line
  /// actually changes, so it never fights a user who is scrolling to inspect
  /// another part of the sheet.
  void _follow(int index) {
    if (index < 0 || index == _followed) return;
    _followed = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const rowExtent = 64.0;
      final target = (index * rowExtent) -
          _scrollController.position.viewportDimension / 2 +
          rowExtent / 2;
      _scrollController.animateTo(
        target.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent),
        duration: context.motion(MotionTokens.albumArt),
        curve: MotionTokens.emphasized,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final draft = widget.draft;
    final controller = ref.read(audioControllerProvider);
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final active = draft.activeIndexAt(position);
    _follow(active);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.lg, vertical: SpacingTokens.xs),
          child: Row(
            children: [
              Text(l10n.syncShiftAll,
                  style:
                      AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
              const Spacer(),
              IconButton(
                tooltip: '-100 ms',
                onPressed: () => widget.onShiftAll(-widget.shiftAll),
                icon: Icon(Icons.remove, color: colors.onSurface),
              ),
              IconButton(
                tooltip: '+100 ms',
                onPressed: () => widget.onShiftAll(widget.shiftAll),
                icon: Icon(Icons.add, color: colors.onSurface),
              ),
            ],
          ),
        ),
        Divider(color: colors.divider, height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemExtent: 64,
            itemCount: draft.entries.length,
            itemBuilder: (context, i) {
              final entry = draft.entries[i];
              final stamped = entry.time != null;
              final isActive = i == active;
              return Container(
                color: isActive
                    ? colors.accent.withOpacity(0.10)
                    : Colors.transparent,
                child: ListTile(
                  dense: true,
                  // Tapping the row auditions the line: jump there and hear
                  // whether the stamp lands right.
                  onTap: stamped ? () => controller.seek(entry.time!) : null,
                  leading: SizedBox(
                    width: 74,
                    child: TextButton(
                      onPressed: () => widget.onEdit(i),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32)),
                      child: Text(
                        stamped ? formatLrcTimestamp(entry.time!) : '--:--',
                        style: AppTextTheme.caption.copyWith(
                          color: stamped
                              ? (isActive ? colors.accent : colors.onSurface)
                              : colors.onSurfaceFaint,
                        ),
                      ),
                    ),
                  ),
                  title: Text(entry.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextTheme.body.copyWith(color: colors.onSurface)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stamped) ...[
                        IconButton(
                          tooltip: '-100 ms',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              widget.onShiftLine(i, -widget.shiftLine),
                          icon: Icon(Icons.keyboard_arrow_left,
                              color: colors.onSurfaceMuted),
                        ),
                        IconButton(
                          tooltip: '+100 ms',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              widget.onShiftLine(i, widget.shiftLine),
                          icon: Icon(Icons.keyboard_arrow_right,
                              color: colors.onSurfaceMuted),
                        ),
                        IconButton(
                          tooltip: 'Clear',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => widget.onClear(i),
                          icon: Icon(Icons.backspace_outlined,
                              size: 18, color: colors.onSurfaceFaint),
                        ),
                      ] else
                        // An unstamped line can be set from the playhead right
                        // here — no need to restart the tap pass for one line.
                        IconButton(
                          tooltip: 'Stamp at playhead',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => widget.onStampAt(i),
                          icon: Icon(Icons.my_location,
                              size: 18, color: colors.accent),
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
