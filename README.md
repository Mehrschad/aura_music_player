# Aura

**A local-first music player for Android, built with Flutter.**

No ads. No cloud. No tracking. Just your music.

[![Build](https://github.com/Mehrschad/aura_music_player/actions/workflows/build_android.yml/badge.svg)](https://github.com/Mehrschad/aura_music_player/actions/workflows/build_android.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-informational)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue)](https://flutter.dev)

---

## Overview

Aura is an open-source, offline music player designed around the idea that a music app should do one thing exceptionally well: play your music, beautifully. The design language is *mature minimalism* — an AMOLED-dark-first UI with Liquid Glass surfaces, typography-led hierarchy, and motion that earns its place. Everything runs locally on your device; no account is required, and nothing leaves your phone.

---

## Features

### 🎵 Playback & Audio Engine
- Gapless playback with full queue management (play next, add to queue, reorder, remove)
- Shuffle and three repeat modes (off, one, all)
- Crossfade, ReplayGain, and speed memory
- Seek by tapping or dragging — with a **custom waveform scrubber** that renders a per-track waveform visualisation as a seek bar

### 📚 Library
- Scans your device storage and indexes your music library
- Browse by **Songs**, **Albums**, and **Artists** in list or grid views
- **Sort** by title, artist, album, year, duration, date added, play count, and more
- Live **search** with ranked results across all fields

### 🎤 Lyrics System
Lyrics are the app's signature feature.
- Parses **LRC files** with standard (`[mm:ss.xx]`) and word-level (`<mm:ss.xx>`) karaoke timings
- **Auto-scrolling synced lyrics** view with tap-to-seek on any line
- **Karaoke mode**: word-by-word highlight fills left-to-right as the track plays
- **Dual-language** display when a translation is available
- Automatically fetches lyrics from **LRCLIB** when no local file exists
- Full **RTL support** — Arabic and Persian lyrics lay out correctly

### ✏️ Tap-to-Sync Editor
Create or correct synced lyrics without any external tools.
- Play the track and tap to stamp each line in real time
- **Fine-tune** individual timestamps with ±0.5s nudges or direct `mm:ss.xx` editing
- Apply a **global offset** to shift all lines at once
- Saves as an `.lrc` file and applies immediately to the lyrics view

### 🎛️ 10-Band Equalizer
- Full-spectrum EQ from 32 Hz to 16 kHz, ±12 dB per band
- Animated **frequency-response curve** drawn in real time behind the band sliders
- Built-in presets: Flat, Bass Boost, Vocal Clarity, Electronic, Acoustic, Hip-Hop, Classical, Rock
- Three **user preset slots** to save and recall your own curves
- **Bass Boost** (0–1000 mB) and **Stereo Widener** with a master enable toggle

### 📋 Playlists
- Create, rename, delete, and reorder user playlists
- **Auto playlists**: Recently Added, Most Played, Recently Played, Favorites — derived automatically from your listening history
- Export any playlist as an `.m3u8` file

### 🧠 Smart Playlists
Build rule-based playlists that update themselves automatically.
- **12 filterable fields**: title, artist, album, genre, year, duration, play count, date added, rating, BPM, and more
- **Operators** adapted to field type: contains, starts with, is/is not, greater/less than, in range, within the last N days
- AND / OR logic, sort field, and a limit by song count or total minutes

### 🏷️ Tag Editor
Edit the metadata stored inside your audio files.
- Edit title, artist, album artist, album, track, disc, year, genre, composer, comment, BPM, compilation flag, and cover art
- **Batch editing**: open multiple tracks at once; only fields you change are written
- Search for **album art** via MusicBrainz Cover Art Archive (no API key needed)
- Changes appear instantly across the entire library without a rescan

### 🏠 Home Screen Widgets & Android Auto
- Three widget sizes (mini, standard, large) with playback controls
- Full **Android Auto** media browser integration: Library → Albums → Artists → tracks

### ⚙️ Settings
- Theme: System / Light / Dark / AMOLED, with a Liquid Glass intensity dial
- Dynamic colour tint derived from album artwork
- Display density and text size
- Library source folders, scan-on-startup, show hidden files
- Playback behaviour on audio interruption
- Last.fm scrobbling integration
- **Backup and restore** settings as JSON

### 🌐 Localisation
Fully internationalised from the ground up. Ships with **English**, **فارسی**, and **العربية**; the entire layout mirrors for RTL locales. Additional languages can be added by contributing a single `.arb` file.

### ♿ Accessibility
- TalkBack / VoiceOver compatible throughout
- Waveform scrubber exposes standard slider semantics
- Respects the OS "reduce animations" setting

---

## Getting Started

Requires Flutter 3.24+ and Dart 3.5+.

```bash
git clone https://github.com/Mehrschad/aura_music_player.git
cd aura_music_player
flutter pub get
flutter run          # runs against a sample library, no device required
flutter test
flutter analyze
```

---

## CI / CD

Every push and pull request runs `flutter analyze`, `flutter test`, and a release APK build via GitHub Actions. Pushing a `v*` tag triggers a release build that produces both an APK and an App Bundle, published automatically as a GitHub Release with generated notes.

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the setup guide, code standards, and PR workflow.

---

## License

MIT — see [LICENSE](LICENSE).
