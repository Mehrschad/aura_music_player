import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/color_scheme.dart';
import '../../../domain/models/song.dart';
import '../../../domain/taste/smart_collection.dart';
import '../../providers/discovery_prefs_provider.dart';
import '../../providers/playback_providers.dart';
import '../../providers/playlist_providers.dart';
import '../player/song_actions_sheet.dart';

/// Prompts for a playlist name (prefilled with [initial]); returns the name via
/// [Navigator.pop], or null on cancel.
class PlaylistNameDialog extends StatefulWidget {
  const PlaylistNameDialog({super.key, required this.initial});

  final String initial;

  @override
  State<PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<PlaylistNameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: const Text('Save playlist'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.onAccent,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Shows the name dialog and, if confirmed, persists [collection] as a real
/// playlist. Shared by the detail page and the card quick-actions sheet.
Future<void> saveCollectionAsPlaylist(
  BuildContext context,
  WidgetRef ref,
  SmartCollection collection,
) async {
  HapticFeedback.selectionClick();
  final messenger = ScaffoldMessenger.of(context);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => PlaylistNameDialog(initial: collection.title),
  );
  if (name == null || name.trim().isEmpty) return;
  final repo = ref.read(playlistRepositoryProvider);
  final created = await repo.create(name.trim());
  await repo.addSongs(created.id, collection.songIds);
  messenger.showSnackBar(
    SnackBar(
      content: Text('Saved "${name.trim()}" to your playlists'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Long-press quick actions for a "For You" card: play, save, or hide.
void showCollectionQuickActions(
  BuildContext context,
  WidgetRef ref,
  SmartCollection collection,
) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('Play'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              ref
                  .read(audioControllerProvider)
                  .playQueue(collection.songs, startIndex: 0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Save to playlists'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              saveCollectionAsPlaylist(context, ref, collection);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Hide'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              ref
                  .read(hiddenCollectionsProvider.notifier)
                  .add(collection.id);
            },
          ),
        ],
      ),
    ),
  );
}

/// Actions for a recommended song row: mark "Not interested" (feeds the engine)
/// or open the full song actions sheet.
void showRecommendationSongActions(
  BuildContext context,
  WidgetRef ref,
  Song song,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.thumb_down_alt_outlined),
            title: const Text('Not interested'),
            subtitle: const Text('Show less like this'),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(sheetCtx).pop();
              ref.read(notInterestedProvider.notifier).add(song.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Got it — we'll show less like this"),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.more_horiz_rounded),
            title: const Text('More actions'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              showSongActions(context, song);
            },
          ),
        ],
      ),
    ),
  );
}
