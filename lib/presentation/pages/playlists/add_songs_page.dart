import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_providers.dart';
import '../../providers/playlist_providers.dart';
import '../../widgets/library/song_list_tile.dart';

/// Opens the multi-select song picker for adding tracks to [playlistId].
Future<void> openAddSongs(BuildContext context, String playlistId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AddSongsPage(playlistId: playlistId),
    ),
  );
}

/// A searchable, multi-select list of the library for adding songs to a
/// playlist. Taste-based suggestions for this playlist lead the list (when the
/// search box is empty) so filling a playlist starts from what fits it.
class AddSongsPage extends ConsumerStatefulWidget {
  const AddSongsPage({super.key, required this.playlistId});
  final String playlistId;

  @override
  ConsumerState<AddSongsPage> createState() => _AddSongsPageState();
}

class _AddSongsPageState extends ConsumerState<AddSongsPage> {
  final Set<String> _selected = {};
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;
    await ref
        .read(playlistRepositoryProvider)
        .addSongs(widget.playlistId, _selected.toList());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final all =
        ref.watch(effectiveSongsProvider).valueOrNull ?? const <Song>[];
    final suggestions =
        ref.watch(playlistSuggestionsProvider(widget.playlistId));
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : [
            for (final s in all)
              if (s.title.toLowerCase().contains(q) ||
                  s.artist.toLowerCase().contains(q) ||
                  s.album.toLowerCase().contains(q))
                s,
          ];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text('Add songs',
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : _confirm,
            child: Text(
              _selected.isEmpty ? 'Add' : 'Add (${_selected.length})',
              style: AppTextTheme.action.copyWith(
                color:
                    _selected.isEmpty ? colors.onSurfaceFaint : colors.accent,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SpacingTokens.md, 0,
                SpacingTokens.md, SpacingTokens.sm),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v),
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'Search your library',
                hintStyle:
                    AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
                prefixIcon: Icon(Icons.search, color: colors.onSurfaceFaint),
                filled: true,
                fillColor: colors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: SpacingTokens.xxl),
              children: [
                if (q.isEmpty && suggestions.isNotEmpty) ...[
                  _subhead(context, 'Suggested for this playlist'),
                  for (final s in suggestions)
                    SongListTile(
                      song: s,
                      selected: _selected.contains(s.id),
                      onTap: () => _toggle(s.id),
                    ),
                  _subhead(context, 'All songs'),
                ],
                for (final s in filtered)
                  SongListTile(
                    song: s,
                    selected: _selected.contains(s.id),
                    onTap: () => _toggle(s.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subhead(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(SpacingTokens.lg, SpacingTokens.md,
            SpacingTokens.lg, SpacingTokens.xs),
        child: Text(
          text.toUpperCase(),
          style: AppTextTheme.caption.copyWith(
            color: context.colors.onSurfaceFaint,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
