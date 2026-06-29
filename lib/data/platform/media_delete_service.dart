import 'package:flutter/services.dart';

/// Bridges to the Android `MediaStore` delete flow via a platform [MethodChannel].
///
/// On Android 11+ the OS shows its own confirmation dialog and grants a
/// one-shot permission to remove the file; [deleteSong] resolves to `true` only
/// after the user confirms. On platforms without the native handler (tests,
/// other OSes) every call resolves to `false` rather than throwing.
class MediaDeleteService {
  const MediaDeleteService();

  static const MethodChannel _channel = MethodChannel('io.mehrschad.aura/media');

  /// Requests deletion of the audio file identified by [songId] (the MediaStore
  /// `_ID`). Returns `true` if the file was actually removed.
  Future<bool> deleteSong(String songId) async {
    try {
      final ok = await _channel.invokeMethod<bool>('deleteSong', {'id': songId});
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
