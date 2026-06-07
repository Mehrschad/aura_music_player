import 'package:dio/dio.dart';

import '../../../domain/repositories/cover_art_repository.dart';

/// Real cover-art fetch: searches MusicBrainz for matching releases, then pulls
/// their images from the Cover Art Archive. Both APIs are free and need no key.
///
/// This is correct and works on device (dio is pure-Dart). It isn't the active
/// source in the sample app (that's [SampleCoverArtRepository], so the grid
/// renders without network); provide this via `coverArtRepositoryProvider` on
/// device, and cache the downloaded bytes alongside the library database.
class MusicBrainzCoverArtRepository implements CoverArtRepository {
  MusicBrainzCoverArtRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              headers: const {'User-Agent': 'Aura/1.0 (music player)'},
            ));

  final Dio _dio;

  @override
  Future<List<CoverArtResult>> search({
    required String artist,
    required String album,
  }) async {
    try {
      // 1. Find candidate releases.
      final query = 'release:"$album" AND artist:"$artist"';
      final res = await _dio.get<Map<String, dynamic>>(
        'https://musicbrainz.org/ws/2/release',
        queryParameters: {'query': query, 'fmt': 'json', 'limit': 6},
      );
      final releases = (res.data?['releases'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      // 2. For each release MBID, the Cover Art Archive exposes images at a
      //    predictable URL; the `front` endpoint redirects to the primary cover.
      final out = <CoverArtResult>[];
      for (final release in releases) {
        final mbid = release['id'] as String?;
        if (mbid == null) continue;
        out.add(CoverArtResult(
          thumbnailUrl: 'https://coverartarchive.org/release/$mbid/front-250',
          fullUrl: 'https://coverartarchive.org/release/$mbid/front',
        ));
      }
      return out;
    } on DioException {
      return const [];
    }
  }
}
