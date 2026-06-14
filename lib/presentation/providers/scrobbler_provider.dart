import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/remote/lastfm/lastfm_client.dart';
import '../../domain/integrations/scrobble_entry.dart';
import 'playback_providers.dart';
import 'settings_providers.dart';
import 'stats_providers.dart';

// ── Scrobble queue (persisted so retries survive app restarts) ──────────────

/// Persisted queue of [ScrobbleEntry]s waiting to be sent to Last.fm.
class ScrobbleQueueNotifier extends StateNotifier<List<ScrobbleEntry>> {
  ScrobbleQueueNotifier() : super(const []) {
    _load();
  }

  static const _key = 'scrobble_queue';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ScrobbleEntry.fromJson)
          .toList();
      if (mounted) state = list;
    } catch (_) {}
  }

  /// Appends one entry and persists the queue.
  void enqueue(ScrobbleEntry entry) {
    state = [...state, entry];
    _persist();
  }

  /// Drops the first [count] entries after a successful scrobble batch.
  void removeFirst(int count) {
    state = state.skip(count).toList();
    _persist();
  }

  void _persist() {
    SharedPreferences.getInstance().then((p) {
      try {
        p.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
      } catch (_) {}
    });
  }
}

final scrobbleQueueProvider =
    StateNotifierProvider<ScrobbleQueueNotifier, List<ScrobbleEntry>>(
  (ref) => ScrobbleQueueNotifier(),
);

// ── Singleton Last.fm HTTP client ────────────────────────────────────────────

final lastFmClientProvider = Provider<LastFmClient>((ref) => LastFmClient());

// ── Scrobbler: wires playback events to the queue and flushes it ─────────────

/// Side-effect provider. Watches the current song for now-playing updates and
/// the play history to enqueue completed plays. Mount with [ref.watch] in the
/// app shell. No-ops when Last.fm is disabled or not authenticated.
final scrobblerProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.lastFmEnabled ||
      settings.lastFmSessionKey.isEmpty ||
      settings.lastFmApiKey.isEmpty) return;

  final client = ref.watch(lastFmClientProvider);
  final apiKey = settings.lastFmApiKey;
  final apiSecret = settings.lastFmApiSecret;
  final sessionKey = settings.lastFmSessionKey;

  // Now-playing update whenever the active song changes.
  ref.listen(currentSongProvider, (_, next) async {
    if (next == null) return;
    final entry = ScrobbleEntry(
      track: next.title,
      artist: next.artist,
      album: next.album,
      songId: next.id,
      timestampSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      durationSec: next.duration.inSeconds,
    );
    try {
      await client.updateNowPlaying(entry, sessionKey, apiKey, apiSecret);
    } catch (_) {}
  });

  // Enqueue newly completed plays and attempt a flush.
  ref.listen(playHistoryProvider, (prev, next) {
    if (prev == null || next.length <= prev.length) return;
    final added = next.sublist(prev.length);
    final queue = ref.read(scrobbleQueueProvider.notifier);
    for (final ev in added) {
      if (!ev.completed) continue;
      queue.enqueue(ScrobbleEntry(
        track: ev.title,
        artist: ev.artist,
        album: ev.album,
        songId: ev.songId,
        timestampSec: ev.atMs ~/ 1000,
        durationSec: ev.msPlayed ~/ 1000,
      ));
    }
    _flush(client, ref.read(scrobbleQueueProvider.notifier),
        sessionKey, apiKey, apiSecret);
  });
});

/// Attempts to send all queued entries, removes them on success.
Future<void> _flush(LastFmClient client, ScrobbleQueueNotifier queue,
    String sessionKey, String apiKey, String apiSecret) async {
  final entries = queue.state;
  if (entries.isEmpty) return;
  try {
    await client.scrobble(entries, sessionKey, apiKey, apiSecret);
    queue.removeFirst(entries.length);
  } catch (_) {} // Retry on next play event
}
