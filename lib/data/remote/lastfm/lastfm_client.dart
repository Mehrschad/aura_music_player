import 'package:dio/dio.dart';

import '../../../domain/integrations/lastfm_signer.dart';
import '../../../domain/integrations/scrobble_entry.dart';

/// HTTP client for the Last.fm API (https://ws.audioscrobbler.com/2.0/).
class LastFmClient {
  LastFmClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const _base = 'https://ws.audioscrobbler.com/2.0/';

  /// Step 1 of auth: obtain an unauthorized token.
  Future<String> getToken(String apiKey, String apiSecret) async {
    final params = <String, String>{
      'method': 'auth.getToken',
      'api_key': apiKey,
    };
    params['api_sig'] = LastFmSigner.sign(params, apiSecret);
    params['format'] = 'json';
    final resp = await _dio.get<Map<String, dynamic>>(_base,
        queryParameters: params);
    final data = resp.data!;
    if (data['error'] != null) {
      throw LastFmException(data['message'] as String? ?? 'unknown');
    }
    return data['token'] as String;
  }

  /// Step 2: exchange an authorized token for a persistent session.
  Future<({String sessionKey, String username})> getSession(
      String token, String apiKey, String apiSecret) async {
    final params = <String, String>{
      'method': 'auth.getSession',
      'api_key': apiKey,
      'token': token,
    };
    params['api_sig'] = LastFmSigner.sign(params, apiSecret);
    params['format'] = 'json';
    final resp = await _dio.get<Map<String, dynamic>>(_base,
        queryParameters: params);
    final data = resp.data!;
    if (data['error'] != null) {
      throw LastFmException(data['message'] as String? ?? 'unknown');
    }
    final session = data['session'] as Map<String, dynamic>;
    return (
      sessionKey: session['key'] as String,
      username: session['name'] as String,
    );
  }

  /// Scrobble up to 50 tracks in a single POST.
  Future<void> scrobble(List<ScrobbleEntry> entries, String sessionKey,
      String apiKey, String apiSecret) async {
    if (entries.isEmpty) return;
    final params = <String, String>{
      'method': 'track.scrobble',
      'api_key': apiKey,
      'sk': sessionKey,
    };
    final batch = entries.take(50).toList();
    for (var i = 0; i < batch.length; i++) {
      final e = batch[i];
      params['artist[$i]'] = e.artist;
      params['track[$i]'] = e.track;
      params['album[$i]'] = e.album;
      params['timestamp[$i]'] = '${e.timestampSec}';
      params['duration[$i]'] = '${e.durationSec}';
    }
    params['api_sig'] = LastFmSigner.sign(params, apiSecret);
    params['format'] = 'json';
    final resp = await _dio.post<Map<String, dynamic>>(
      _base,
      data: params,
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    final data = resp.data!;
    if (data['error'] != null) {
      throw LastFmException(data['message'] as String? ?? 'unknown');
    }
  }

  /// Notify Last.fm of the currently-playing track (best-effort).
  Future<void> updateNowPlaying(ScrobbleEntry entry, String sessionKey,
      String apiKey, String apiSecret) async {
    final params = <String, String>{
      'method': 'track.updateNowPlaying',
      'api_key': apiKey,
      'sk': sessionKey,
      'artist': entry.artist,
      'track': entry.track,
      'album': entry.album,
      'duration': '${entry.durationSec}',
    };
    params['api_sig'] = LastFmSigner.sign(params, apiSecret);
    params['format'] = 'json';
    try {
      await _dio.post<void>(
        _base,
        data: params,
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
    } catch (_) {} // Best-effort; never fail playback
  }
}

/// Thrown when Last.fm returns an error code in its JSON envelope.
class LastFmException implements Exception {
  const LastFmException(this.message);
  final String message;
  @override
  String toString() => 'LastFmException: $message';
}
