import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/library/id3_genres.dart';
import '../../../domain/library/tag_edit.dart';
import '../../../domain/models/song.dart';
import '../../providers/cover_art_providers.dart';
import '../../providers/library_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';

Future<void> openTagEditor(BuildContext context, List<Song> songs) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: context.motion(MotionTokens.screen),
    pageBuilder: (_, __, ___) => TagEditorPage(songs: songs),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: MotionTokens.standard),
      child: child,
    ),
  ));
}

enum _F {
  title,
  artist,
  albumArtist,
  album,
  track,
  disc,
  year,
  composer,
  comment,
  bpm,
}

class TagEditorPage extends ConsumerStatefulWidget {
  const TagEditorPage({super.key, required this.songs});

  final List<Song> songs;

  @override
  ConsumerState<TagEditorPage> createState() => _TagEditorPageState();
}

class _TagEditorPageState extends ConsumerState<TagEditorPage> {
  final _controllers = <_F, TextEditingController>{};
  final _multiple = <_F, bool>{};
  final _touched = <_F>{};

  String? _genre;
  bool _genreTouched = false;
  bool _genreMultiple = false;

  late bool _compilation;
  bool _compTouched = false;

  late bool _hasArtwork;
  bool _artworkTouched = false;

  List<Song> get _songs => widget.songs;
  bool get _isBatch => _songs.length > 1;

  @override
  void initState() {
    super.initState();
    _initText(_F.title, (s) => s.title);
    _initText(_F.artist, (s) => s.artist);
    _initText(_F.albumArtist, (s) => s.albumArtist);
    _initText(_F.album, (s) => s.album);
    _initText(_F.track, (s) => s.trackNumber?.toString());
    _initText(_F.disc, (s) => s.discNumber?.toString());
    _initText(_F.year, (s) => s.year?.toString());
    _initText(_F.composer, (s) => s.composer);
    _initText(_F.comment, (s) => s.comment);
    _initText(_F.bpm, (s) => s.bpm?.toString());

    final genre = commonValue(_songs, (s) => s.genre);
    _genre = genre.value;
    _genreMultiple = genre.multiple;

    final comp = commonValue(_songs, (s) => s.compilation);
    _compilation = comp.value ?? false;

    final art = commonValue(_songs, (s) => s.hasArtwork);
    _hasArtwork = art.value ?? false;
  }

  void _initText(_F field, String? Function(Song) selector) {
    final common = commonValue(_songs, selector);
    _multiple[field] = common.multiple;
    final controller = TextEditingController(text: common.value ?? '');
    _controllers[field] = controller;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(_F f) {
    if (!_touched.contains(f)) return null;
    final t = _controllers[f]!.text.trim();
    return t;
  }

  int? _int(_F f) {
    if (!_touched.contains(f)) return null;
    return int.tryParse(_controllers[f]!.text.trim());
  }

  Future<void> _save() async {
    final edit = SongTagEdit(
      title: _text(_F.title),
      artist: _text(_F.artist),
      albumArtist: _text(_F.albumArtist),
      album: _text(_F.album),
      composer: _text(_F.composer),
      comment: _text(_F.comment),
      year: _int(_F.year),
      trackNumber: _int(_F.track),
      discNumber: _int(_F.disc),
      bpm: _int(_F.bpm),
      genre: _genreTouched ? _genre : null,
      compilation: _compTouched ? _compilation : null,
      hasArtwork: _artworkTouched ? _hasArtwork : null,
    );

    if (!edit.isEmpty) {
      final edited = edit.applyToAll(_songs);
      ref.read(tagOverridesProvider.notifier).apply(edited);
      // Device persistence (no-op in-app; real audiotagger write on device).
      final writer = ref.read(tagWriterProvider);
      await Future.wait(_songs.map((s) => writer.write(s, edit)));
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).maybePop();
    messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tagsSaved)));
  }

  Future<void> _pickGenre() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: RadiusTokens.rLg)),
      builder: (ctx) => _GenreSheet(initial: _genre),
    );
    if (picked == null) return;
    setState(() {
      _genre = picked.trim().isEmpty ? null : picked.trim();
      _genreTouched = true;
      _genreMultiple = false;
    });
  }

  Future<void> _fetchArtwork() async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: RadiusTokens.rLg)),
      builder: (ctx) =>
          _ArtworkSheet(artist: _songs.first.artist, album: _songs.first.album),
    );
    if (applied == true) {
      setState(() {
        _hasArtwork = true;
        _artworkTouched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(
          _isBatch ? l10n.editingCount(_songs.length) : l10n.editTags,
          style: AppTextTheme.title.copyWith(color: colors.onSurface),
        ),
        actions: [
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, SpacingTokens.md,
            SpacingTokens.lg, SpacingTokens.xxl),
        children: [
          _artworkSection(context),
          const SizedBox(height: SpacingTokens.lg),
          _field(_F.title, l10n.tagTitle),
          _field(_F.artist, l10n.tagArtist),
          _field(_F.albumArtist, l10n.tagAlbumArtist),
          _field(_F.album, l10n.tagAlbum),
          Row(
            children: [
              Expanded(child: _field(_F.track, l10n.tagTrack, number: true)),
              const SizedBox(width: SpacingTokens.md),
              Expanded(child: _field(_F.disc, l10n.tagDisc, number: true)),
              const SizedBox(width: SpacingTokens.md),
              Expanded(child: _field(_F.year, l10n.tagYear, number: true)),
            ],
          ),
          _genreField(context),
          _field(_F.composer, l10n.tagComposer),
          _field(_F.comment, l10n.tagComment, maxLines: 3),
          _field(_F.bpm, l10n.tagBpm, number: true),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.tagCompilation,
                style: AppTextTheme.body.copyWith(color: colors.onSurface)),
            subtitle: _isBatch && !_compTouched && _mixedCompilation()
                ? Text(l10n.multipleValues,
                    style: AppTextTheme.caption
                        .copyWith(color: colors.onSurfaceFaint))
                : null,
            value: _compilation,
            onChanged: (v) => setState(() {
              _compilation = v;
              _compTouched = true;
            }),
          ),
        ],
      ),
    );
  }

  bool _mixedCompilation() => commonValue(_songs, (s) => s.compilation).multiple;

  Widget _artworkSection(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        ClipRRect(
          borderRadius: RadiusTokens.brMd,
          child: AuraArtwork(
            seed: _songs.first.artworkSeed,
            size: 88,
            hasArtwork: _hasArtwork,
          ),
        ),
        const SizedBox(width: SpacingTokens.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.artwork,
                  style:
                      AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
              const SizedBox(height: SpacingTokens.sm),
              Wrap(
                spacing: SpacingTokens.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: _fetchArtwork,
                    icon: const Icon(Icons.image_search, size: 18),
                    label: Text(l10n.fetchArtwork),
                  ),
                  if (_hasArtwork)
                    TextButton(
                      onPressed: () => setState(() {
                        _hasArtwork = false;
                        _artworkTouched = true;
                      }),
                      child: Text(l10n.removeArtwork),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(_F f, String label, {bool number = false, int maxLines = 1}) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final multiple = _multiple[f] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.md),
      child: TextField(
        controller: _controllers[f],
        maxLines: maxLines,
        keyboardType: number ? TextInputType.number : null,
        onChanged: (_) => _touched.add(f),
        style: AppTextTheme.body.copyWith(color: colors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
          hintText: multiple ? l10n.multipleValues : null,
          hintStyle:
              AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
          filled: true,
          fillColor: colors.surfaceElevated,
          border: const OutlineInputBorder(
              borderRadius: RadiusTokens.brSm, borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _genreField(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final showMultiple = _genreMultiple && !_genreTouched;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.md),
      child: InkWell(
        onTap: _pickGenre,
        borderRadius: RadiusTokens.brSm,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.tagGenre,
            labelStyle:
                AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
            filled: true,
            fillColor: colors.surfaceElevated,
            border: const OutlineInputBorder(
                borderRadius: RadiusTokens.brSm, borderSide: BorderSide.none),
            suffixIcon:
                Icon(Icons.arrow_drop_down, color: colors.onSurfaceMuted),
          ),
          child: Text(
            showMultiple ? l10n.multipleValues : (_genre ?? '—'),
            style: AppTextTheme.body.copyWith(
                color: showMultiple || _genre == null
                    ? colors.onSurfaceFaint
                    : colors.onSurface),
          ),
        ),
      ),
    );
  }
}

class _GenreSheet extends StatefulWidget {
  const _GenreSheet({this.initial});
  final String? initial;

  @override
  State<_GenreSheet> createState() => _GenreSheetState();
}

class _GenreSheetState extends State<_GenreSheet> {
  late final TextEditingController _custom =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            child: TextField(
              controller: _custom,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: l10n.chooseGenre,
                suffixIcon: IconButton(
                  icon: Icon(Icons.check, color: colors.accent),
                  onPressed: () => Navigator.of(context).pop(_custom.text),
                ),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final g in kCommonGenres)
                  ListTile(
                    title: Text(g,
                        style: AppTextTheme.body
                            .copyWith(color: colors.onSurface)),
                    trailing: g == widget.initial
                        ? Icon(Icons.check, color: colors.accent)
                        : null,
                    onTap: () => Navigator.of(context).pop(g),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkSheet extends ConsumerWidget {
  const _ArtworkSheet({required this.artist, required this.album});
  final String artist;
  final String album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final results =
        ref.watch(coverArtSearchProvider((artist: artist, album: album)));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.fetchArtwork,
                style: AppTextTheme.title.copyWith(color: colors.onSurface)),
            const SizedBox(height: SpacingTokens.md),
            results.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SpacingTokens.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Text(l10n.lyricsNone,
                  style: AppTextTheme.body
                      .copyWith(color: colors.onSurfaceMuted)),
              data: (items) => GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: SpacingTokens.sm,
                crossAxisSpacing: SpacingTokens.sm,
                children: [
                  for (final item in items)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: ClipRRect(
                        borderRadius: RadiusTokens.brSm,
                        child: AuraArtwork(
                          seed: item.seed ?? '$artist$album',
                          size: 100,
                          hasArtwork: true,
                        ),
                      ),
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
