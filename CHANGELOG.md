# Changelog

All notable changes to Aura are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is
[SemVer](https://semver.org/).

## [Unreleased]

### Added — Player & shell polish (phase 3)
- **Resume last session**: the queue, current track, position, and
  shuffle/repeat are remembered across cold starts and restored **paused**.
  New `AudioController.restoreQueue`, a `PlaybackPersistence` store, and an
  invisible `PlaybackPersistor` that saves on change / heartbeat / background.
- **Ultra glass**: new `GlassIntensity.ultra` setting — a deeper blur with a
  richer frosted tint, selectable in Settings.

### Changed
- Mini player and bottom nav bar now share one fully-rounded stadium shell;
  the mini-player progress is a slim inset rounded capsule.
- Mini player gains a **previous-track** control.
- Now Playing transport regrouped to `shuffle · prev · play/pause · next ·
  repeat`; queue moved to the top bar. Shuffle/repeat toggles redesigned with a
  glowing accent disc and a springy press bump.
- Smoother, weightier open/close animation for Now Playing; the mini player
  now "catches" the closing page with an elastic settle.

### Fixed
- Bottom nav glass pill now mirrors correctly in RTL (fa/ar) via
  `PositionedDirectional`.
- Soft keyboard no longer re-opens on the Search page after returning from Now
  Playing (focus is dropped before the route is pushed).

## [1.0.0] - 2026-06-07

First public release. Highlights below; per-area detail follows.

- Library, Artists, Albums, Playlists, Search with grid/list/compact modes and sorting
- Background audio engine seam, mini player and immersive Now Playing screen
- Waveform scrubber, gapless/queue management, drag-reorder playlists with m3u8 export
- Lyrics engine (LRC + word-level karaoke, RTL, dual-language) and tap-to-sync editor
- 10-band equalizer with presets, bass boost and stereo widener
- Tag editor (single + batch) with MusicBrainz cover-art fetch
- Smart-playlist rules engine; full Settings with theme/locale/density and backup
- Home-screen widget state + media-browser tree for Android Auto
- Reduced-motion + accessibility pass; en/fa/ar localization

### Added — Build step 14: polish & performance
- `context.motion()` reduced-motion helper; applied to all screen-route
  transitions and the EQ curve tween (breathing artwork / press-scale already
  honoured `disableAnimations`).
- Accessibility: waveform scrubber now a semantic slider (label + value +
  increase/decrease seek); Now Playing artwork labelled as an image; mini-player
  play/pause tooltip.
- `runOffMainThread` (`compute`) helper; LRCLIB synced-lyrics parsing moved to a
  background isolate, with the scan/tag-parse pattern documented.
- Tests: reduced-motion helper + waveform slider semantics.

### Added — Build step 13: home-screen widgets + Android Auto
- Pure `HomeWidgetState` + `homeWidgetStateFrom` mapper and `toWidgetData()`
  serialisation; `HomeWidgetSync` seam (active `NoopHomeWidgetSync`, documented
  `home_widget` + `workmanager` impl) and a shell bridge that pushes on change.
- In-app widget preview (mini / standard / large) with live, working controls,
  reachable from Settings → Integrations.
- Pure `mediaChildren` media-browser tree (root → Library/Albums/Artists →
  tracks) for Android Auto via the audio_service handler;
  `mediaBrowserChildrenProvider` over the edit-aware library.
- pubspec placeholders for `home_widget` / `workmanager`. Tests: widget-state
  mapper + media-browser tree.

### Added — Build step 12: settings + i18n pass
- `AppSettings` model (appearance / library / playback / lyrics / integrations)
  with `toJson`/`fromJson` for backup; `SettingsRepository` seam (in-memory
  active, `shared_preferences` documented) and a persisting `SettingsNotifier`.
- App root rebuilt as a `ConsumerWidget`: theme mode + dark flavour, locale,
  visual density and text scale all driven by settings. Glass intensity wired to
  the nav bar; dynamic-colour toggle gates the Now Playing wash.
- Settings screen with all sections, source-folder management, settings backup
  export/import, licenses page, and an in-app language switcher.
- i18n: full `en`/`fa`/`ar` key parity verified; locale override applied at the
  app root.
- `AppInfo` constants. Settings entry point added to the Library header. Tests:
  settings model/mappers/notifier + settings widget test.

### Added — Build step 11: smart-playlist rules engine
- Pure model + evaluator: `SmartPlaylist` / `SmartRule` (12 fields, typed
  operator sets, AND/OR, sort, limit by count or minutes) and
  `evaluateSmartPlaylist` with injectable `now` for deterministic date rules.
- `SmartPlaylistRepository` seam: active `InMemorySmartPlaylistRepository`
  (seeded "With Lyrics" + "Long Tracks") + documented Isar path.
- Providers: definitions, by-id, and live `smartPlaylistSongsProvider` evaluated
  against `effectiveSongsProvider`; `saveSmartPlaylist` / `deleteSmartPlaylist`.
- Rule-builder editor (field/operator/value rows adapting to field kind, match
  all/any, sort, limit). Smart-playlist section on the Playlists tab; `.smart`
  mode added to the shared detail page with an edit-rules action.
- Tests: evaluator (all operators/match/limit/sort) + editor widget test.

### Added — Build step 10: tag editor
- `Song` extended with composer / comment / bpm / compilation.
- Pure `SongTagEdit` (apply single + batch, only-touched-fields semantics) and
  `commonValue` (shared-vs-"Multiple values" detection).
- `tagOverridesProvider` + `effectiveSongsProvider`: tag edits apply on top of
  the scan and propagate across library, albums, artists, search and playlists
  without a rescan. Library and playlist derived providers repointed.
- Tag editor page: single + batch fields, ID3 genre picker (`id3_genres.dart`),
  artwork section with fetch grid. Entry from the song actions sheet (single)
  and the playlist overflow menu (batch).
- Cover-art seam: `CoverArtRepository` with active `SampleCoverArtRepository`
  and real `MusicBrainzCoverArtRepository` (Cover Art Archive).
- Device persistence seam: documented `AudiotaggerTagWriter` + active
  `NoopTagWriter` via `tagWriterProvider`.
- Tests: `SongTagEdit` / `commonValue` units + tag-editor widget test.

### Added — Build step 9: equalizer
- `EqualizerController` seam: active `VisualEqualizerController` (cross-platform
  10-band state model) + documented `SystemEqualizerController` (Android
  `equalizer_flutter` bridge).
- Pure EQ logic: preset gains (8 presets), `clampGain`, `matchPreset`, and
  `eqGainAt` curve sampling.
- Equalizer page: `CustomPainter` response curve with gradient fill +
  `TweenAnimationBuilder` smoothing, ten vertical band sliders, preset chips with
  three user slots, Bass Boost (0–1000 mB) and Stereo Widener, enable/reset.
- Added `RadiusTokens.brPill`. Entry point from Now Playing. Tests: EQ preset/
  curve units + EQ widget test.

### Added — Build step 8: tap-to-sync editor
- Pure `SyncDraft` model: stamp / undo / setTime / shiftLine (±0.5s) / shiftAll /
  `toLrc`, with `formatLrcTimestamp` / `parseLrcTimestamp`. Seeds from existing
  plain or synced lyrics, or from pasted text.
- Sync editor screen: tap-to-sync phase (large tap target, prev/next lines,
  waveform strip, undo/restart) and fine-tune phase (per-line ±0.5s, tap-to-edit
  timestamp, global shift-all).
- Save builds `.lrc`, copies to clipboard, and writes to a session lyrics
  override (`lyricsOverridesProvider`) so the synced result appears immediately
  in the lyrics view; `currentLyricsProvider` now consults overrides first.
- Entry point from the lyrics screen. Tests: `SyncDraft` unit tests + sync-editor
  widget test.

### Added — Build step 7: lyrics engine
- Pure `parseLyrics` / `parseLrc` / `parsePlainLyrics`: standard + word-level
  LRC, `[offset:]`, multi-timestamp lines, metadata skipping; binary-search
  `currentLineIndex`.
- `LyricsRepository` seam: active `SampleLyricsRepository` (bundled synced /
  karaoke / dual-language lyrics) + real `LrcLibLyricsRepository` (LRCLIB via
  dio, exact + fuzzy match). `dio` activated in `pubspec.yaml`.
- Synced lyrics page: auto-scroll to ~38%, current/past/future styling, tap-to-
  seek, blurred-art background, per-line RTL via `Bidi.detectRtlDirectionality`.
- Karaoke word-fill on the active line (clipped accent overlay), single/dual
  language toggle, and small/medium/large text size. Entry point from Now Playing.
- Tests: LRC parser (incl. word-level, offset, multi-timestamp), line lookup,
  and a lyrics widget test.

### Added — Build step 6: playlists + queue management
- `PlaylistRepository` seam: active `InMemoryPlaylistRepository` (create/rename/
  delete/add/remove/reorder, streamed live) + documented Isar stub.
- Auto playlists (Recently added / Most played / Recently played / Favorites),
  derived purely from the song index; favourites now surface as a playlist.
- Playlist detail page: play all / shuffle, drag-reorder, swipe-remove, rename,
  delete, and `.m3u8` export (pure `buildM3u8`; clipboard in-app, file on device).
- Queue mutation across both audio backends (play-next / add-to-queue / remove /
  move); reorderable + swipe-to-remove queue panel with tap-to-jump.
- Per-song actions sheet (play next / add to queue / add to playlist) in Library
  and Search.
- Removed the now-unused `SectionScaffold` placeholder.
- Tests: m3u8 builder, auto-playlist logic, in-memory repo, fake-engine queue
  mutations, and a playlists widget test.

### Added — Build step 5: waveform scrubber
- `WaveformScrubber` (`CustomPainter`): thin vertical bars, full-opacity accent
  behind the playhead and 30% ahead; tap/drag to seek with a floating time
  tooltip. Replaces the step-4 slider in Now Playing.
- Pure, deterministic `generateWaveform` (seed-derived, centre-weighted
  envelope) and `resampleAmplitudes` — the single swap point for real on-device
  PCM analysis.
- Unit tests for the generator and resampler; tap-to-seek widget test.

### Added — Build step 4: Now Playing + mini-player upgrades
- Full-screen Now Playing page: breathing album art, track text, functional
  seek scrubber, transport controls (prev / ±10s / play-pause / next), and
  shuffle / repeat / queue controls. Double-tap art to seek ±10s.
- Shared-element `Hero` transition from the mini player to Now Playing over a
  slide-up + fade route.
- Mini-player gestures: swipe to skip (haptics), swipe down to dismiss.
- `SeedPalette` muted dynamic-colour wash/accent (saturation clamped to 40%);
  stand-in for `palette_dart` until on-device artwork.
- Session favourites store (`favoritesProvider`) and a read-only queue panel
  with tap-to-jump.
- 72px `AnimatedIcon` play/pause button; reduced-motion aware. SeedPalette unit
  test + Now Playing widget test.

### Added — Build step 3: audio engine
- `AudioController` interface with two backends: active pure-Dart
  `FakeAudioController` (timer-driven simulated playback) and real
  `JustAudioController` (just_audio + just_audio_background: gapless queue,
  lock-screen / notification controls).
- `PlaybackState` / `RepeatMode` / `PlaybackStatus` domain models; position kept
  on a separate stream from the core state.
- Playback providers (controller, state stream, position stream, current-song
  and has-media helpers).
- Tap-to-play wired across Library and Search (the list becomes the queue).
- Functional Liquid Glass mini player above the nav bar with live progress
  line; scroll insets reserve space for it when visible.
- Unit tests for the fake engine's transport/queue/repeat/shuffle logic and an
  end-to-end mini-player widget test. `just_audio` deps activated in
  `pubspec.yaml`.

### Added — Build step 2: library
- `LibraryRepository` interface with two implementations: active in-memory
  `SampleLibraryRepository` and a documented on-device `DeviceLibraryRepository`
  (on_audio_query scan + Isar cache, off-isolate mapping).
- Domain models: `Song`, `Album`, `Artist`, `LibrarySort` / `SortField` /
  `DisplayMode`.
- Pure, unit-tested library logic: `sortSongs` (direction-aware, stable, nulls
  always last), `groupAlbums`, `groupArtists`, ranked `searchSongs`.
- Library UI: switchable list / grid / compact views, grouped Albums and
  Artists screens, live ranked Search, glass sort sheet.
- `AuraArtwork` deterministic placeholder, `AsyncStateView` loading/error/empty
  handling, `PressScale`, shared `SectionHeader`, and `playerBarInset`.
- Riverpod providers for the async song index and derived sorted/grouped/search
  views; step-2 dependencies activated in `pubspec.yaml`.

### Added — Build step 1: foundation
- Design-token system: spacing, radius, motion, colour (AMOLED/dark/light),
  typography (Inter, disciplined weights).
- `GlassSurface` Liquid Glass primitive with intensity levels.
- App shell: floating glass bottom navigation, 5 sections via `IndexedStack`,
  Riverpod tab state, accessibility semantics and 44×44 touch targets.
- Internationalization scaffolding (gen-l10n + .arb) with en / fa / ar.
- Project hygiene: strict analysis options, MIT license, Android CI workflow,
  shell widget tests.
