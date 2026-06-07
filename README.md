# Aura

A refined, local-first music player for Android & iOS, built with Flutter.

![Build](https://github.com/aura/aura_music_player/actions/workflows/build_android.yml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-informational)
![Flutter](https://img.shields.io/badge/Flutter-3.24.0-blue)

> Mature minimalism — every pixel earns its place. Liquid Glass applied with
> surgical precision, AMOLED-dark first, typography-led hierarchy.

This repository is being built in deliberate stages (see the build order
below) rather than dumped all at once, so every layer compiles and runs before
the next is added.

## Status

| Step | Area | State |
|------|------|-------|
| 1 | Project setup · theme system · bottom nav shell | ✅ done |
| 2 | Library scan · list/grid · sort & filter | ✅ done |
| 3 | Audio engine (just_audio + audio_service) | ✅ done |
| 4 | Mini player + Now Playing | ✅ done |
| 5 | Waveform scrubber | ✅ done |
| 6 | Playlists + queue | ✅ done |
| 7 | Lyrics engine (LRC, karaoke) | ✅ done |
| 8 | Tap-to-sync editor | ✅ done |
| 9 | Equalizer (system + visual) | ✅ done |
| 10 | Tag editor | ✅ done |
| 11 | Smart-playlist rules | ✅ done |
| 12 | Settings + full i18n pass | ✅ done |
| 13 | Home-screen widgets + Android Auto | ✅ done |
| 14 | Polish & performance | ✅ done |
| 15 | Release: CI/CD, first tag | ✅ done |

All 15 build steps are complete — Aura **v1.0.0**. The app compiles and runs
against an in-memory sample library and a fake audio engine; the real device
backends are wired behind interfaces and swapped in via provider overrides.

## What step 1 delivers

- **Design-token foundation** — `SpacingTokens`, `RadiusTokens`, `MotionTokens`,
  a typed `AppColors` theme extension (AMOLED / dark / light) and `AppTextTheme`
  (Inter, weights 300/400/500/600). No magic numbers, no raw hex, no inline
  text styles anywhere in widgets.
- **Liquid Glass** — a single `GlassSurface` primitive (BackdropFilter blur,
  faint tint, 1px inner-highlight border) with an intensity enum mapped to the
  Off/Subtle/Medium/Strong setting.
- **App shell** — floating glass bottom nav (5 tabs), `IndexedStack` so each
  section keeps its state, Riverpod-driven tab selection, 44×44 touch targets,
  `Semantics` labels, press-scale feedback.
- **i18n wired from day one** — `gen-l10n` + `.arb`, English default plus Farsi
  and Arabic so RTL mirroring is exercised immediately.

## What step 2 delivers

- **Repository seam** — UI and providers depend only on a `LibraryRepository`
  interface. Two implementations sit behind it: a curated `SampleLibraryRepository`
  (active everywhere, no device needed) and a documented `DeviceLibraryRepository`
  (on-device `on_audio_query` scan + Isar cache + off-isolate mapping) that drops
  in by overriding one provider on a real phone.
- **Pure, tested domain logic** — `sortSongs` (8 fields, direction-aware, stable,
  with missing values always sorting last in *both* directions), `groupAlbums` /
  `groupArtists`, and a ranked `searchSongs` matcher. All side-effect-free and
  covered by unit tests.
- **Full library UI** — Library (list / grid / compact, switchable), Albums
  (grouped grid), Artists (grouped list with album/song counts), and live
  ranked Search, all populated and interactive. A glass sort sheet drives the
  sort field + direction.
- **Deterministic placeholder artwork** — `AuraArtwork` derives a calm, muted
  per-album gradient from a seed, so empty art is on-brand until real thumbnails
  land on device.

## What step 3 delivers

- **Audio-engine seam** — UI depends only on an `AudioController` interface.
  Two backends: an active pure-Dart `FakeAudioController` that simulates
  playback (timer-driven position, queue advance, shuffle, all repeat modes) so
  the player is fully live without audio hardware, and a real
  `JustAudioController` (just_audio + just_audio_background — gapless
  `ConcatenatingAudioSource`, `MediaItem` lock-screen/notification controls)
  that drops in on device via one provider override plus a documented one-time
  background-session setup.
- **Tap to play** — selecting a track in Library or Search starts playback with
  that list as the queue, from the tapped index.
- **Functional mini player** — a Liquid Glass card above the nav bar with
  artwork, title/artist, play-pause, skip, and a live progress line; it
  collapses away when nothing is loaded. Position rides its own stream so the
  progress line updates without rebuilding the rest of the player.
- **Tested** — the fake engine's transport, queue advance, and repeat/shuffle
  logic are unit-tested deterministically; an end-to-end widget test confirms
  tapping a song surfaces and controls the mini player.

The grand Now Playing screen and the mini-player gestures / shared-element
transition are step 4.

## What step 4 delivers

- **Now Playing screen** — full-screen immersive player: large album art that
  breathes (1.0 → 1.015, 4s) while playing, title/artist, a functional seek
  scrubber with time labels, transport (prev / −10s / play-pause / +10s / next),
  and shuffle / repeat / queue controls. Double-tap the art to seek ±10s.
- **Shared-element transition** — tapping the mini player flies its artwork up
  into the Now Playing screen via a `Hero`, over a slide-up + fade route.
- **Mini-player gestures** — swipe left/right to skip (with haptics), swipe down
  to dismiss the player.
- **Dynamic-colour wash** — the background tint and accent are derived from the
  artwork (a `palette_dart` stand-in via `SeedPalette`), saturation clamped to
  40% so it never turns garish.
- **Favourites & queue** — a session favourites store (moves to Isar in step 6)
  drives the heart toggle; a read-only queue panel lists the queue with the
  current track highlighted and tap-to-jump (reorder/remove land in step 6).
- **72px AnimatedIcon play/pause**, reduced-motion aware throughout; tested via
  a SeedPalette unit test and an end-to-end open-and-control widget test.

The waveform scrubber (`CustomPainter`) replaces the slider in step 5.

## What step 5 delivers

- **Waveform scrubber** — a `CustomPainter` of thin vertical bars (2px wide,
  1.5px gap): full-opacity accent behind the playhead, 30% ahead. Tap or drag to
  seek, with a time tooltip that floats above the thumb while scrubbing. It's a
  drop-in replacement for the step-4 slider in Now Playing.
- **Deterministic per-track waveform** — bar heights come from a pure,
  seed-derived generator (`generateWaveform`) with a centre-weighted envelope,
  so every track has a stable shape that never flickers between rebuilds. On
  device this is the one swap point for real PCM analysis; the painter and
  scrubber stay unchanged.
- **Resolution-independent** — a fixed-resolution profile is resampled to
  whatever bar count the width allows, keeping a track's shape recognisable at
  any size. Only the bars repaint as the position advances.
- **Tested** — generator determinism/range and the resampler are unit-tested; a
  widget test confirms tapping at 75% seeks to ~75% of the track.

## What step 6 delivers

- **Playlists** — a `PlaylistRepository` seam with an active, fully-functional
  in-memory store (create / rename / delete / add / remove / reorder, streamed
  live) and a documented Isar implementation for on-device persistence.
- **Auto playlists** — Recently added (30-day window), Most played, Recently
  played, and Favorites, all derived purely from the song index; the session
  favourites store now surfaces as the Favorites playlist (and graduates to Isar
  on device).
- **Playlist detail** — play all / shuffle, drag-to-reorder and swipe-to-remove
  (user playlists), rename / delete, and `.m3u8` export (copied to clipboard
  in-app; written to a file via the picker on device). Auto playlists are
  read-only but still playable and exportable.
- **Queue management** — the audio engine gained play-next / add-to-queue /
  remove / move (fake and real backends); the queue panel is now reorderable
  with swipe-to-remove and tap-to-jump.
- **Song actions** — a per-row overflow menu (play next, add to queue, add to
  playlist) across Library and Search.
- **Tested** — m3u8 builder, auto-playlist derivations, the in-memory repo, the
  engine's queue mutations, and a playlists widget test.

## What step 7 delivers

- **LRC parser** — pure `parseLyrics` handling standard `[mm:ss.xx]` lines,
  word-level `<mm:ss.xx>` timings (karaoke), plain text, the global `[offset:]`
  correction, multiple timestamps per line, and metadata-tag skipping. Fully
  unit-tested, including a binary-search current-line lookup.
- **Lyrics source seam** — active `SampleLyricsRepository` (bundled lyrics
  exercising synced, karaoke and dual-language) and a real `LrcLibLyricsRepository`
  (LRCLIB over dio, exact + fuzzy ±5s match); the device composite (cache →
  embedded tags → LRCLIB) is documented.
- **Synced lyrics view** — auto-scrolls the active line to ~38% from the top,
  highlights current / past / future lines, tap any line to seek, with a blurred
  album-art background. Per-line direction is auto-detected, so RTL lyrics (and
  RTL translations) lay out correctly.
- **Karaoke** — word-level left-to-right fill on the active line, computed from
  the word timings; only that one line repaints per tick.
- **Dual-language & text size** — single/dual toggle (when translations exist)
  and a small/medium/large size cycle. Reachable from the Now Playing screen.

## What step 8 delivers

- **Tap-to-sync** — play the track and tap on the beat as each line is sung; the
  current line is the large tap target, with the previous/next lines flanking it
  and a waveform strip for timing reference. Undo and restart are one tap away.
- **Fine-tune** — a list of lines with their timestamps: nudge any line ±0.5s,
  tap a timestamp to edit it as `mm:ss.xx`, or shift every line at once with the
  global offset.
- **Pure, tested model** — all of this is a side-effect-free `SyncDraft` (stamp /
  undo / setTime / shiftLine / shiftAll / `toLrc`), with `mm:ss.xx`
  format/parse helpers. Fully unit-tested, plus the required sync-editor widget
  test.
- **Save** — builds `.lrc`, copies it to the clipboard, and writes it to a
  session lyrics override so the synced result shows up immediately in the
  lyrics view (persists to Isar / a `.lrc` file or embedded tag on device).
- Seeds from existing plain or synced lyrics, or from pasted text when a track
  has none. Reachable from the lyrics screen.

## What step 9 delivers

- **Equalizer screen** — a PowerAmp-inspired 10-band EQ (32 Hz … 16 kHz, ±12 dB):
  a `CustomPainter` frequency-response curve with a gradient fill, drawn behind
  ten draggable vertical band sliders. The curve eases via a `TweenAnimationBuilder`
  when a preset is applied.
- **Presets** — Flat, Bass Boost, Vocal Clarity, Electronic, Acoustic, Hip-Hop,
  Classical, Rock, plus three user slots (save the current curve, tap to recall).
- **Bass Boost (0–1000 mB)** and a **Stereo Widener**, with an overall enable
  toggle and reset.
- **Controller seam** — an active cross-platform `VisualEqualizerController`
  (the state model that drives the curve and, on device, a DSP chain) and a
  documented `SystemEqualizerController` for Android's `equalizer_flutter` bridge.
- **Pure, tested logic** — preset gains, range clamping, preset matching, and the
  curve-sampling function, plus the required EQ widget test. Reachable from the
  Now Playing screen.

## What step 10 delivers

- **Tag editor** — edit Title, Artist, Album Artist, Album, Track/Disc/Year,
  Genre (picker over common ID3 genres + free text), Composer, Comment, BPM and
  the Compilation flag, plus an artwork section.
- **Batch editing** — open the editor on several tracks at once (e.g. a whole
  playlist via its overflow menu); shared fields prefill, differing fields show
  *Multiple values*, and only the fields you actually touch are written across
  the selection.
- **Live, no-rescan updates** — saves land in a session `tagOverridesProvider`
  applied on top of the scan via `effectiveSongsProvider`, so edits show
  immediately across Library, Albums, Artists, Search and Playlists. On device
  the same save also writes to the files (documented `AudiotaggerTagWriter`).
- **Cover-art fetch** — a search grid backed by a `CoverArtRepository` seam:
  active `SampleCoverArtRepository` (offline placeholders) and a real
  `MusicBrainzCoverArtRepository` (MusicBrainz → Cover Art Archive, no key).
- **Pure, tested core** — `SongTagEdit` (apply single/batch) and `commonValue`
  (shared-vs-multiple detection), plus the required tag-editor widget test.
  `Song` gained composer / comment / bpm / compilation fields.

## What step 11 delivers

- **Smart-playlist engine** — a pure `evaluateSmartPlaylist` that filters by
  rules (AND/OR), sorts by any field, and applies a limit (by song count or by
  total minutes). Twelve fields across text / integer / duration / date /
  boolean kinds, each with its valid operator set (is, is not, contains, starts
  with, greater/less than, in range). Date rules compare an age-in-days, so they
  read as "added within the last N days"; deterministic via an injectable `now`.
- **Rule builder** — create or edit a smart playlist: name, match all/any, a
  list of field-operator-value rule rows (operators and value inputs adapt to
  the field kind — numeric, range, or true/false), sort field + direction, and
  the limit. Rules re-evaluate live against the edit-aware library.
- **Integrated** — smart playlists get their own section on the Playlists tab,
  open into the shared detail view (read-only, with an edit-rules action), and
  persist via a `SmartPlaylistRepository` seam (active in-memory, Isar on device).
- **Tested** — the evaluator across every operator/match/limit/sort case, plus a
  rule-builder widget test.

## What step 12 delivers

- **Settings screen** — Appearance (theme System/Light/Dark/AMOLED, Liquid Glass
  intensity, dynamic colour, text size, display density, language), Library
  (source folders add/remove, scan-on-startup, show-hidden, re-scan), Playback
  (crossfade, ReplayGain, gapless, speed memory, interruption behaviour),
  Equalizer (opens the EQ), Lyrics (auto-fetch, Genius key, clear cache),
  Integrations (Last.fm, Android Auto) and About.
- **Live wiring** — theme mode + dark flavour, locale, display density and text
  scale flow from `settingsProvider` into the app root and apply instantly;
  glass intensity drives the nav bar; the dynamic-colour toggle gates the Now
  Playing wash. Preferences persist through a `SettingsRepository` seam
  (in-memory active, `shared_preferences` on device).
- **Backup** — export settings to JSON (clipboard) and import by paste, with
  round-tripped `toJson`/`fromJson` and graceful fallback on bad input.
- **i18n pass** — every UI string localised across `en`, `fa` and `ar` with full
  key parity; an in-app language switcher drives the locale (RTL mirrors the
  whole layout). The `.arb` structure is ready for the remaining launch locales.
- **Tested** — settings model (copyWith, JSON round-trip, fallback), the app-root
  mappers, notifier persistence, plus a settings widget test.

## What step 13 delivers

- **Home-screen widget state** — a pure `homeWidgetStateFrom` mapper turning
  playback into what the mini / standard / large widgets show, plus
  `toWidgetData()` serialisation to the primitive key-value map `home_widget`
  hands the native layouts. A shell bridge pushes updates whenever state changes.
- **Live preview** — an in-app preview screen (Settings → Integrations → Home
  screen widgets) rendering all three sizes from live playback, with working
  transport, shuffle and repeat — so the layouts are reviewable without
  installing the native widget.
- **Android Auto / media browser** — a pure `mediaChildren` tree (root →
  Library / Albums / Artists → tracks) evaluated against the edit-aware library:
  exactly what an `audio_service` handler's `getChildren` serves to Android Auto.
- **Seams documented** — `HomeWidgetSync` (active no-op, `home_widget` +
  `workmanager` on device) and the media-browser handler wiring.
- **Tested** — the widget-state mapper/serialisation and the full browse tree.

## What step 14 delivers

- **Reduced motion** — a `context.motion()` helper collapses durations to instant
  when the OS "remove animations" setting is on, now applied to every screen
  transition and the EQ curve tween (the foundational breathing artwork and
  press-scale already honoured it). Animations complete instantly rather than
  being removed, so layout stays intact.
- **Accessibility** — the custom waveform scrubber now exposes proper slider
  semantics (label + value + increase/decrease seek), the Now Playing artwork is
  labelled as an image, and the mini-player play/pause control gained a
  tooltip/label. Combined with the existing per-control labels and system font
  scaling, the player is navigable by TalkBack/VoiceOver.
- **Off-main-thread parsing** — a `runOffMainThread` (`compute`) helper; LRCLIB
  synced-lyrics parsing runs on a background isolate, and the same pattern is
  documented for the device library scan and tag parsing, keeping the UI thread
  free.
- **Tested** — the reduced-motion helper and the waveform's screen-reader slider.

## Running it

Requires Flutter 3.24+ / Dart 3.5+.

```bash
flutter pub get      # also generates lib/core/l10n/app_localizations.dart
flutter run
flutter test
flutter analyze      # written against the strict ruleset in analysis_options.yaml
```

The Library, Albums, Artists, Search and Playlists tabs are all functional
against the sample library; tapping a song plays it through the mini player,
which expands to the Now Playing screen.

### A couple of notes

- **Inter font** isn't bundled yet; text falls back to the platform sans-serif
  until the weights are dropped into `assets/fonts/` (see the commented block in
  `pubspec.yaml`). No error in the meantime.
- The full dependency list from the design spec lives in `pubspec.yaml` as a
  commented, per-step manifest. Each block is uncommented when its build step
  begins, keeping `flutter pub get` green today.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, the
non-negotiable code standards (design tokens, full localization, tests), and the
PR workflow. Bug reports and feature requests use the issue templates.

## Releases & CI

- **CI** (`.github/workflows/build_android.yml`) runs `flutter analyze`,
  `flutter test` and a release APK build on every push and PR.
- **Releases** (`.github/workflows/release.yml`) trigger on a `v*` tag: it builds
  the release APK + App Bundle and publishes a GitHub Release with generated
  notes and the artifacts attached.

To cut a release: bump `version:` in `pubspec.yaml`, move the `[Unreleased]`
changelog entries under a dated version heading, then:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## License

MIT — see [LICENSE](LICENSE).
