import '../../domain/repositories/cover_art_repository.dart';

/// Returns deterministic placeholder candidates so the artwork-fetch grid is
/// fully exercisable offline. Each result carries a seed the UI renders via
/// [AuraArtwork] rather than a network image.
class SampleCoverArtRepository implements CoverArtRepository {
  const SampleCoverArtRepository();

  @override
  Future<List<CoverArtResult>> search({
    required String artist,
    required String album,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final base = '$artist::$album';
    return [
      for (var i = 0; i < 6; i++)
        CoverArtResult(thumbnailUrl: '', fullUrl: '', seed: '$base#$i'),
    ];
  }
}
