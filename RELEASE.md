# Release Guide

## Pre-release checklist

Before tagging a release, verify:

- [ ] `CHANGELOG.md` `[Unreleased]` section is up to date
- [ ] Version bump in `pubspec.yaml` (`version: X.Y.Z+BUILD`)
- [ ] All tests pass locally: `flutter test`
- [ ] No analysis errors: `flutter analyze`
- [ ] Signing config present (`android/key.properties` + keystore, **never committed**)
- [ ] App launches cleanly on a physical device or emulator
- [ ] Now Playing, mini player, library scan, and playback all work end-to-end

## How to create a release

1. **Rename the changelog section** — change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`.
2. **Commit the bump:**
   ```bash
   git add pubspec.yaml CHANGELOG.md
   git commit -m "chore: bump version to X.Y.Z"
   ```
3. **Tag the commit:**
   ```bash
   git tag -a vX.Y.Z -m "Release X.Y.Z"
   git push origin vX.Y.Z
   ```
   The `v` prefix is required — CI only publishes releases for tags matching `v*`.

## What CI does on a tag push

The `Build Android` workflow (`build_android.yml`) runs on every push. When the ref is a `v*` tag it does **two extra steps** after the normal build:

1. **Build release AAB** — `flutter build appbundle --release`
2. **Publish GitHub Release** — uploads `app-release.apk` and `app-release.aab` as release assets via `softprops/action-gh-release@v2`.

`fail_on_unmatched_files: true` ensures CI fails loudly if either artifact is missing rather than silently publishing an empty release.

The APK is also always uploaded as a **workflow artifact** (Actions → the run → "release-apk"), retained for 30 days, regardless of whether it's a tag push.

## Verifying a release

After the workflow completes:

1. Open the repository's **Releases** page on GitHub.
2. Confirm the new release appears with both `app-release.apk` and `app-release.aab` attached.
3. Download and install the APK on a device to do a final smoke test.

## Rollback

If a release needs to be pulled:

1. **Delete the GitHub Release** (and its tag) from the Releases page — this removes the downloadable assets.
2. Optionally delete the git tag locally and remotely:
   ```bash
   git tag -d vX.Y.Z
   git push origin :refs/tags/vX.Y.Z
   ```
3. Publish a patch release (e.g. `vX.Y.Z+1`) with the fix applied.

> **Note:** Deleting a release does not remove previously installed APKs from users' devices. If the issue is a data-corrupting bug, also increment `pubspec.yaml`'s build number so Android treats it as a true upgrade.
