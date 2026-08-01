import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/models/song.dart';

/// Hands [song] to the OS share sheet.
///
/// Shares the audio file itself whenever the path points at a readable file, so
/// the recipient gets the actual track. When the library only holds a media id
/// (content-URI backed devices) or the file has since moved, it degrades to a
/// text card with title / artist / album rather than failing.
Future<void> shareSong(BuildContext context, Song song) async {
  final origin = _shareOrigin(context);

  var hasFile = false;
  try {
    hasFile = song.filePath.isNotEmpty && await File(song.filePath).exists();
  } catch (_) {
    hasFile = false; // unreadable path — fall back to text
  }

  try {
    if (hasFile) {
      await Share.shareXFiles(
        [XFile(song.filePath, mimeType: 'audio/*')],
        text: songShareText(song),
        sharePositionOrigin: origin,
      );
    } else {
      await Share.share(
        songShareText(song),
        subject: song.title,
        sharePositionOrigin: origin,
      );
    }
  } catch (_) {
    // No share target / user cancelled at the platform level — nothing to do.
  }
}

/// The text that accompanies a shared track.
String songShareText(Song song) {
  final buffer = StringBuffer('${song.title} — ${song.artist}');
  if (song.album.isNotEmpty && song.album != song.title) {
    buffer.write('\n${song.album}');
  }
  return buffer.toString();
}

/// The rect the share sheet should anchor to (required for iPad popovers,
/// ignored elsewhere). Null when the triggering widget is already gone — e.g.
/// the action sheet was popped before sharing.
Rect? _shareOrigin(BuildContext context) {
  if (!context.mounted) return null;
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
