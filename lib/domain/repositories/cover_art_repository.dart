/// A candidate cover-art image found for a release.
class CoverArtResult {
  const CoverArtResult({required this.thumbnailUrl, required this.fullUrl, this.seed});

  final String thumbnailUrl;
  final String fullUrl;

  /// For the sample source: a seed used to render a deterministic placeholder
  /// instead of a network image.
  final String? seed;
}

/// Searches for cover art by artist + album.
///
/// [SampleCoverArtRepository] is active (deterministic placeholders, no
/// network). [MusicBrainzCoverArtRepository] is the real Cover Art Archive
/// client.
abstract interface class CoverArtRepository {
  Future<List<CoverArtResult>> search({required String artist, required String album});
}
