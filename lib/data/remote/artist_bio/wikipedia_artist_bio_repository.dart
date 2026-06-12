import 'package:dio/dio.dart';

/// Fetches a short artist biography from Wikipedia — free, no API key.
///
/// Strategy:
///   1. Direct REST summary lookup (`/api/rest_v1/page/summary/<name>`),
///      following redirects. Works for most well-known artists.
///   2. Fallback: full-text search (`action=query&list=search`) biased with
///      the word "musician", then summary of the top hit. Catches artists
///      whose page title carries a disambiguator like "(singer)".
///
/// Returns the plain-text summary paragraph, or null when nothing usable is
/// found (disambiguation pages are rejected).
class WikipediaArtistBioRepository {
  WikipediaArtistBioRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://en.wikipedia.org',
              headers: const {'User-Agent': 'Aura (https://github.com/aura)'},
            ));

  final Dio _dio;

  Future<String?> bioFor(String artistName) async {
    final name = artistName.trim();
    if (name.isEmpty) return null;

    final direct = await _summaryOf(name);
    if (direct != null) return direct;

    // Search fallback — bias toward music articles.
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/w/api.php',
        queryParameters: {
          'action': 'query',
          'list': 'search',
          'srsearch': '$name musician',
          'srlimit': 1,
          'format': 'json',
        },
      );
      final hits = ((res.data?['query']
              as Map<String, dynamic>?)?['search'] as List?) ??
          const [];
      if (hits.isEmpty) return null;
      final title = (hits.first as Map<String, dynamic>)['title'] as String?;
      if (title == null) return null;
      return _summaryOf(title);
    } on DioException {
      return null;
    }
  }

  Future<String?> _summaryOf(String title) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
        queryParameters: {'redirect': 'true'},
      );
      final data = res.data;
      if (data == null) return null;
      // Disambiguation pages have an extract but aren't a biography.
      if (data['type'] == 'disambiguation') return null;
      final extract = (data['extract'] as String?)?.trim();
      return (extract == null || extract.isEmpty) ? null : extract;
    } on DioException {
      return null;
    }
  }
}
