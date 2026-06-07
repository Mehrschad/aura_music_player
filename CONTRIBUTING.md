# Contributing to Aura

Thanks for your interest in improving Aura. This guide covers local setup, the
code standards the project holds itself to, and the contribution workflow.

## Development setup

Aura pins **Flutter 3.24.0** (Dart 3.5+). Match it locally — CI builds against it
and a few APIs differ in later versions (e.g. `Color.withOpacity` vs
`withValues`).

```bash
flutter --version          # ensure 3.24.0
flutter pub get            # also generates localizations (lib/core/l10n/app_localizations*.dart)
flutter analyze            # must pass with zero issues
flutter test               # unit + widget tests
flutter run                # launches with the in-memory sample library
```

The app runs out of the box against an in-memory sample library and a fake audio
engine — no device media or API keys required. The real backends
(`just_audio`, `on_audio_query`, LRCLIB, MusicBrainz, `home_widget`, …) live
behind interfaces and are swapped in via provider overrides on device; see the
"…Repository" / "…Controller" seams in `lib/data/`.

## Architecture

Clean-ish layering under `lib/`:

- `domain/` — pure models and logic (no Flutter imports beyond `foundation`).
  Parsers, the smart-playlist evaluator, the EQ math, the media-browser tree,
  etc. live here and are unit-tested in isolation.
- `data/` — repository/controller implementations. Each capability has an
  interface, an active in-memory/sample implementation, and a documented device
  implementation.
- `presentation/` — Riverpod providers, pages and widgets.
- `core/` — design tokens, theme, l10n, shared utilities.

State is [Riverpod](https://riverpod.dev). UI depends on providers, never on a
concrete repository.

## Non-negotiable code standards

These are enforced in review (and partly by `flutter analyze`):

- **No hardcoded user-facing strings** — everything goes through `l10n` (add keys
  to `lib/core/l10n/app_en.arb`, then translate in `app_fa.arb` / `app_ar.arb`).
- **No magic numbers** — spacing/radii/motion come from `SpacingTokens`,
  `RadiusTokens`, `MotionTokens`.
- **No raw hex colours in widgets** — use `context.colors` (`AppColors`); colours
  are defined only in `color_scheme.dart`.
- **No inline `TextStyle`** — use `AppTextTheme`; styles are defined only in
  `typography.dart` (`.copyWith` for per-use tweaks is fine).
- **Respect reduced motion** — wrap animation durations with `context.motion(...)`.
- **Accessibility** — label interactive controls (`Semantics` / `tooltip`); keep
  touch targets ≥ 44×44.
- **Tests** — every provider/logic unit gets a test; the EQ, lyrics sync editor
  and Now Playing carry widget tests. Add tests with your change.
- **No `print`** — use a logger; `avoid_print` is an analyzer error.

## Adding a language

1. Copy `lib/core/l10n/app_en.arb` to `app_<locale>.arb` and translate the values
   (keep the keys).
2. Add the locale to `supportedLocales` (generated from the `.arb` files) and run
   `flutter pub get`.
3. For RTL languages, verify mirroring in the running app — layout flips
   automatically via the locale.

## Workflow

1. Fork and branch from `main` (`feat/...`, `fix/...`).
2. Keep changes focused; update `CHANGELOG.md` under `[Unreleased]`.
3. Ensure `flutter analyze` and `flutter test` pass.
4. Open a PR using the template; describe the change and link any issue.

## Releases

Maintainers cut releases by bumping `version:` in `pubspec.yaml`, moving the
`[Unreleased]` changelog entries under a dated version heading, and pushing a tag
(`vMAJOR.MINOR.PATCH`). The release workflow builds the APK + App Bundle and
publishes a GitHub Release.

By contributing you agree your work is licensed under the project's MIT License.
