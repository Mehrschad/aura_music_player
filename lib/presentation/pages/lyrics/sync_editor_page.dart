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

  static const _shiftLine = Duration(milliseconds: 500);
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
    if (result == null) return;
    final parsed = parseLrcTimestamp(result);
    if (parsed != null) setState(() => _draft = _draft!.setTime(index, parsed));
  }

  void _save() {
    final draft = _draft;
    final song = ref.read(currentSongProvider);
    if (draft == null || song == null) return;
    final lrc = draft.toLrc();
    final lyrics = parseLrc(lrc);
    ref.read(lyricsOverridesProvider.notifier).save(song.id, lyrics);
    Clipboard.setData(ClipboardData(text: lrc));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).maybePop();
    messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).syncSaved)));
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(SpacingTokens.md),
          child: SegmentedButton<_Mode>(
            segments: [
              ButtonSegment(value: _Mode.tap, label: Text(l10n.syncModeTap)),
              ButtonSegment(value: _Mode.tune, label: Text(l10n.syncModeTune)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        Expanded(
          child: _mode == _Mode.tap
              ? _TapPhase(
                  draft: _draft!,
                  onTap: _stampNow,
                  onUndo: () => setState(() => _draft = _draft!.undo()),
                )
              : _TunePhase(
                  draft: _draft!,
                  shiftLine: _shiftLine,
                  shiftAll: _shiftAll,
                  onShiftLine: (i, d) =>
                      setState(() => _draft = _draft!.shiftLine(i, d)),
                  onShiftAll: (d) =>
                      setState(() => _draft = _draft!.shiftAll(d)),
                  onEdit: _editTimestamp,
                ),
        ),
      ],
    );
  }
}

class _TapPhase extends ConsumerWidget {
  const _TapPhase({
    required this.draft,
    required this.onTap,
    required this.onUndo,
  });

  final SyncDraft draft;
  final VoidCallback onTap;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final song = ref.watch(currentSongProvider);
    final playing =
        ref.watch(playbackStateProvider).valueOrNull?.playing ?? false;
    final controller = ref.read(audioControllerProvider);
    final cursor = draft.cursor;
    final accent = SeedPalette.accent(song?.artworkSeed ?? 'sync');

    String lineAt(int i) =>
        (i >= 0 && i < draft.entries.length) ? draft.entries[i].text : '';

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.syncTapHint,
                      textAlign: TextAlign.center,
                      style: AppTextTheme.caption
                          .copyWith(color: colors.onSurfaceFaint)),
                  const SizedBox(height: SpacingTokens.xxl),
                  if (cursor > 0)
                    Text(lineAt(cursor - 1),
                        textAlign: TextAlign.center,
                        style: AppTextTheme.body
                            .copyWith(color: colors.onSurfaceFaint)),
                  const SizedBox(height: SpacingTokens.md),
                  Text(
                    cursor < draft.entries.length
                        ? lineAt(cursor)
                        : '\u2713',
                    textAlign: TextAlign.center,
                    style: AppTextTheme.heroTitle.copyWith(
                        color: cursor < draft.entries.length
                            ? accent
                            : colors.onSurface),
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  if (cursor + 1 < draft.entries.length)
                    Text(lineAt(cursor + 1),
                        textAlign: TextAlign.center,
                        style: AppTextTheme.body
                            .copyWith(color: colors.onSurfaceMuted)),
                ],
              ),
            ),
          ),
        ),
        if (song != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
            child: WaveformScrubber(
              duration: song.duration,
              accent: accent,
              seed: song.artworkSeed,
              isPlaying: playing,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(SpacingTokens.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: l10n.syncRestart,
                onPressed: () => controller.seek(Duration.zero),
                icon: Icon(Icons.replay, color: colors.onSurfaceMuted),
              ),
              PlayPauseButton(
                playing: playing,
                onTap: controller.togglePlayPause,
                size: 56,
              ),
              IconButton(
                tooltip: l10n.syncUndo,
                onPressed: draft.hasStarted ? onUndo : null,
                icon: Icon(Icons.undo, color: colors.onSurfaceMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TunePhase extends StatelessWidget {
  const _TunePhase({
    required this.draft,
    required this.shiftLine,
    required this.shiftAll,
    required this.onShiftLine,
    required this.onShiftAll,
    required this.onEdit,
  });

  final SyncDraft draft;
  final Duration shiftLine;
  final Duration shiftAll;
  final void Function(int index, Duration delta) onShiftLine;
  final void Function(Duration delta) onShiftAll;
  final void Function(int index) onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.lg, vertical: SpacingTokens.sm),
          child: Row(
            children: [
              Text(l10n.syncShiftAll,
                  style:
                      AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
              const Spacer(),
              IconButton(
                onPressed: () => onShiftAll(-shiftAll),
                icon: Icon(Icons.remove, color: colors.onSurface),
              ),
              IconButton(
                onPressed: () => onShiftAll(shiftAll),
                icon: Icon(Icons.add, color: colors.onSurface),
              ),
            ],
          ),
        ),
        Divider(color: colors.divider, height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: draft.entries.length,
            itemBuilder: (context, i) {
              final entry = draft.entries[i];
              final stamp =
                  entry.time == null ? '--:--' : formatLrcTimestamp(entry.time!);
              return ListTile(
                dense: true,
                leading: TextButton(
                  onPressed: entry.time == null ? null : () => onEdit(i),
                  child: Text(stamp,
                      style: AppTextTheme.caption.copyWith(
                          color: entry.time == null
                              ? colors.onSurfaceFaint
                              : colors.onSurface)),
                ),
                title: Text(entry.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTextTheme.body.copyWith(color: colors.onSurface)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: entry.time == null
                          ? null
                          : () => onShiftLine(i, -shiftLine),
                      icon: Icon(Icons.keyboard_arrow_left,
                          color: colors.onSurfaceMuted),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: entry.time == null
                          ? null
                          : () => onShiftLine(i, shiftLine),
                      icon: Icon(Icons.keyboard_arrow_right,
                          color: colors.onSurfaceMuted),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
