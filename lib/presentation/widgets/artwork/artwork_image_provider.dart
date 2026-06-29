import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// A Flutter [ImageProvider] that reads embedded cover art from an audio file
/// at up to 2048 px using [ArtworkType.AUDIO] (MediaMetadataRetriever on
/// Android), then lets Flutter's image cache and scaler handle display at any
/// widget size.
///
/// Why not [QueryArtworkWidget]?
///   • That widget passes the *widget display size* as the MediaStore request
///     size, so a 48 dp thumbnail fetches a 48 px bitmap and looks terrible on
///     high-DPI screens — even though the source file may have 1000+ px art.
///   • It uses [Image.memory] whose cache key is the raw bytes, not the song
///     ID, so the same artwork is re-decoded from disk for every widget instance.
///
/// This provider fixes both problems:
///   • Always requests 2048 px so Android returns the embedded picture at its
///     native resolution (it will NOT upscale if the source is smaller).
///   • Uses [id] as the cache key so artwork is decoded once and shared
///     across mini player, song list, album grid, and Now Playing.
class ArtworkImageProvider extends ImageProvider<ArtworkImageProvider> {
  const ArtworkImageProvider({required this.id});

  final int id;

  static final _query = OnAudioQuery();

  @override
  Future<ArtworkImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ArtworkImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    ArtworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      debugLabel: 'Artwork(id=$id)',
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await _query.queryArtwork(
      id,
      ArtworkType.AUDIO,
      size: 2048,
      quality: 100,
      format: ArtworkFormat.JPEG,
    );
    if (bytes == null || bytes.isEmpty) {
      throw Exception('No artwork for id=$id');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is ArtworkImageProvider && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
