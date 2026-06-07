import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/library/smart_playlist.dart';
import '../../providers/smart_playlist_providers.dart';

String fieldLabel(RuleField f, AppLocalizations l) => switch (f) {
      RuleField.title => l.fieldTitle,
      RuleField.artist => l.fieldArtist,
      RuleField.album => l.fieldAlbum,
      RuleField.genre => l.fieldGenre,
      RuleField.year => l.fieldYear,
      RuleField.duration => l.fieldDuration,
      RuleField.playCount => l.fieldPlayCount,
      RuleField.lastPlayed => l.fieldLastPlayed,
      RuleField.dateAdded => l.fieldDateAdded,
      RuleField.bitrate => l.fieldBitrate,
      RuleField.hasLyrics => l.fieldHasLyrics,
      RuleField.hasArtwork => l.fieldHasArtwork,
    };

String operatorLabel(RuleOperator o, AppLocalizations l) => switch (o) {
      RuleOperator.is_ => l.opIs,
      RuleOperator.isNot => l.opIsNot,
      RuleOperator.contains => l.opContains,
      RuleOperator.doesNotContain => l.opDoesNotContain,
      RuleOperator.startsWith => l.opStartsWith,
      RuleOperator.greaterThan => l.opGreaterThan,
      RuleOperator.lessThan => l.opLessThan,
      RuleOperator.inRange => l.opInRange,
    };

Future<void> openSmartPlaylistEditor(BuildContext context,
    [SmartPlaylist? existing]) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: context.motion(MotionTokens.screen),
    pageBuilder: (_, __, ___) => SmartPlaylistEditorPage(existing: existing),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: MotionTokens.standard),
      child: child,
    ),
  ));
}

class _RuleDraft {
  _RuleDraft(this.field, this.op, String value, String value2)
      : value = TextEditingController(text: value),
        value2 = TextEditingController(text: value2);

  RuleField field;
  RuleOperator op;
  final TextEditingController value;
  final TextEditingController value2;

  void dispose() {
    value.dispose();
    value2.dispose();
  }

  SmartRule toRule() => SmartRule(
      field: field, op: op, value: value.text.trim(), value2: value2.text.trim());
}

class SmartPlaylistEditorPage extends ConsumerStatefulWidget {
  const SmartPlaylistEditorPage({super.key, this.existing});
  final SmartPlaylist? existing;

  @override
  ConsumerState<SmartPlaylistEditorPage> createState() =>
      _SmartPlaylistEditorPageState();
}

class _SmartPlaylistEditorPageState
    extends ConsumerState<SmartPlaylistEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _limitValue;
  late RuleMatch _match;
  late RuleField _sortField;
  late bool _sortDescending;
  late SmartLimitKind _limitKind;
  final List<_RuleDraft> _rules = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _match = e?.match ?? RuleMatch.all;
    _sortField = e?.sortField ?? RuleField.title;
    _sortDescending = e?.sortDescending ?? false;
    _limitKind = e?.limit.kind ?? SmartLimitKind.none;
    _limitValue =
        TextEditingController(text: e == null || e.limit.value == 0 ? '' : '${e.limit.value}');
    for (final r in e?.rules ?? const <SmartRule>[]) {
      _rules.add(_RuleDraft(r.field, r.op, r.value, r.value2));
    }
    if (_rules.isEmpty) _addRule();
  }

  @override
  void dispose() {
    _name.dispose();
    _limitValue.dispose();
    for (final r in _rules) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRule() {
    final ops = operatorsFor(ruleFieldKind(RuleField.title));
    _rules.add(_RuleDraft(RuleField.title, ops.first, '', ''));
  }

  void _onFieldChanged(_RuleDraft draft, RuleField field) {
    final ops = operatorsFor(ruleFieldKind(field));
    setState(() {
      draft.field = field;
      if (!ops.contains(draft.op)) draft.op = ops.first;
      if (ruleFieldKind(field) == RuleFieldKind.boolean &&
          draft.value.text != 'true' &&
          draft.value.text != 'false') {
        draft.value.text = 'true';
      }
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? 'Smart playlist' : _name.text.trim();
    final limit = SmartLimit(
      kind: _limitKind,
      value: int.tryParse(_limitValue.text.trim()) ?? 0,
    );
    final sp = SmartPlaylist(
      id: widget.existing?.id ?? '',
      name: name,
      match: _match,
      rules: [for (final r in _rules) r.toRule()],
      sortField: _sortField,
      sortDescending: _sortDescending,
      limit: limit,
    );
    await saveSmartPlaylist(ref, sp);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(l10n.smartPlaylistNew,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: l10n.delete,
              icon: Icon(Icons.delete_outline, color: colors.onSurfaceMuted),
              onPressed: () async {
                await deleteSmartPlaylist(ref, widget.existing!.id);
                if (mounted) Navigator.of(context).maybePop();
              },
            ),
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, SpacingTokens.md,
            SpacingTokens.lg, SpacingTokens.xxl),
        children: [
          TextField(
            controller: _name,
            style: AppTextTheme.body.copyWith(color: colors.onSurface),
            decoration: InputDecoration(
              labelText: l10n.playlistNameHint,
              filled: true,
              fillColor: colors.surfaceElevated,
              border: const OutlineInputBorder(
                  borderRadius: RadiusTokens.brSm, borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          SegmentedButton<RuleMatch>(
            segments: [
              ButtonSegment(value: RuleMatch.all, label: Text(l10n.matchAll)),
              ButtonSegment(value: RuleMatch.any, label: Text(l10n.matchAny)),
            ],
            selected: {_match},
            onSelectionChanged: (s) => setState(() => _match = s.first),
          ),
          const SizedBox(height: SpacingTokens.md),
          for (final draft in _rules) _ruleRow(draft),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(_addRule),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addRule),
            ),
          ),
          Divider(color: colors.divider, height: SpacingTokens.xl),
          _sortRow(l10n, colors),
          const SizedBox(height: SpacingTokens.sm),
          _limitRow(l10n, colors),
        ],
      ),
    );
  }

  Widget _ruleRow(_RuleDraft draft) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final kind = ruleFieldKind(draft.field);
    final ops = operatorsFor(kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<RuleField>(
                  isExpanded: true,
                  value: draft.field,
                  dropdownColor: colors.surfaceElevated,
                  style: AppTextTheme.body.copyWith(color: colors.onSurface),
                  items: [
                    for (final f in RuleField.values)
                      DropdownMenuItem(value: f, child: Text(fieldLabel(f, l10n))),
                  ],
                  onChanged: (f) => f == null ? null : _onFieldChanged(draft, f),
                ),
              ),
              if (_rules.length > 1)
                IconButton(
                  icon: Icon(Icons.close, color: colors.onSurfaceFaint),
                  onPressed: () => setState(() {
                    _rules.remove(draft);
                    draft.dispose();
                  }),
                ),
            ],
          ),
          DropdownButton<RuleOperator>(
            isExpanded: true,
            value: draft.op,
            dropdownColor: colors.surfaceElevated,
            style: AppTextTheme.body.copyWith(color: colors.onSurface),
            items: [
              for (final o in ops)
                DropdownMenuItem(value: o, child: Text(operatorLabel(o, l10n))),
            ],
            onChanged: (o) =>
                o == null ? null : setState(() => draft.op = o),
          ),
          _valueInput(draft, kind),
        ],
      ),
    );
  }

  Widget _valueInput(_RuleDraft draft, RuleFieldKind kind) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    if (kind == RuleFieldKind.boolean) {
      final v = draft.value.text == 'false' ? 'false' : 'true';
      return DropdownButton<String>(
        isExpanded: true,
        value: v,
        dropdownColor: colors.surfaceElevated,
        style: AppTextTheme.body.copyWith(color: colors.onSurface),
        items: const [
          DropdownMenuItem(value: 'true', child: Text('true')),
          DropdownMenuItem(value: 'false', child: Text('false')),
        ],
        onChanged: (s) => setState(() => draft.value.text = s ?? 'true'),
      );
    }

    final numeric = kind != RuleFieldKind.text;
    final field = TextField(
      controller: draft.value,
      keyboardType: numeric ? TextInputType.number : null,
      style: AppTextTheme.body.copyWith(color: colors.onSurface),
      decoration: InputDecoration(
        isDense: true,
        hintText: l10n.ruleValue,
        hintStyle: AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
      ),
    );

    if (draft.op != RuleOperator.inRange) return field;
    return Row(
      children: [
        Expanded(child: field),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
          child: Text(l10n.ruleValueTo,
              style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted)),
        ),
        Expanded(
          child: TextField(
            controller: draft.value2,
            keyboardType: TextInputType.number,
            style: AppTextTheme.body.copyWith(color: colors.onSurface),
            decoration: const InputDecoration(isDense: true),
          ),
        ),
      ],
    );
  }

  Widget _sortRow(AppLocalizations l10n, AppColors colors) {
    return Row(
      children: [
        Text(l10n.sortBy,
            style: AppTextTheme.body.copyWith(color: colors.onSurface)),
        const SizedBox(width: SpacingTokens.md),
        Expanded(
          child: DropdownButton<RuleField>(
            isExpanded: true,
            value: _sortField,
            dropdownColor: colors.surfaceElevated,
            style: AppTextTheme.body.copyWith(color: colors.onSurface),
            items: [
              for (final f in RuleField.values)
                DropdownMenuItem(value: f, child: Text(fieldLabel(f, l10n))),
            ],
            onChanged: (f) => setState(() => _sortField = f ?? _sortField),
          ),
        ),
        Text(l10n.descending,
            style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted)),
        Switch(
          value: _sortDescending,
          onChanged: (v) => setState(() => _sortDescending = v),
        ),
      ],
    );
  }

  Widget _limitRow(AppLocalizations l10n, AppColors colors) {
    return Row(
      children: [
        Expanded(
          child: DropdownButton<SmartLimitKind>(
            isExpanded: true,
            value: _limitKind,
            dropdownColor: colors.surfaceElevated,
            style: AppTextTheme.body.copyWith(color: colors.onSurface),
            items: [
              DropdownMenuItem(
                  value: SmartLimitKind.none, child: Text(l10n.limitNone)),
              DropdownMenuItem(
                  value: SmartLimitKind.songs, child: Text(l10n.limitSongs)),
              DropdownMenuItem(
                  value: SmartLimitKind.minutes, child: Text(l10n.limitMinutes)),
            ],
            onChanged: (k) => setState(() => _limitKind = k ?? SmartLimitKind.none),
          ),
        ),
        if (_limitKind != SmartLimitKind.none) ...[
          const SizedBox(width: SpacingTokens.md),
          SizedBox(
            width: 88,
            child: TextField(
              controller: _limitValue,
              keyboardType: TextInputType.number,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: const InputDecoration(isDense: true),
            ),
          ),
        ],
      ],
    );
  }
}
