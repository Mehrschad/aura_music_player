import 'package:aura_music_player/domain/models/app_settings.dart';
import 'package:aura_music_player/presentation/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Turns on the platform "disable animations" flag for the current test, and
/// clears it again on tear-down.
///
/// The app runs several deliberately endless animations — the search loading
/// shimmer, the now-playing bars, the waveform, the Now Playing beat ticker and
/// ambient drift. `pumpAndSettle` waits for the frame pipeline to go quiet, so
/// any test that mounts the shell while one of those loops would time out
/// instead of settling.
///
/// Every one of those animations already stops when the user asks for reduced
/// motion, so switching the flag on is what lets a test settle — and it
/// exercises a path real users get, rather than faking anything.
void useReducedMotion(WidgetTester tester) {
  final dispatcher = tester.platformDispatcher;
  dispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
}

/// Starts the app as a returning user rather than a first launch.
///
/// The shell pushes [OnboardingPage] from a post-frame callback whenever
/// `onboardingSeen` is false, which is the default. Tests that exercise the
/// library, the nav bar, playlists or selection want the normal shell, not the
/// welcome flow sitting on top of it.
Override pastOnboarding() => settingsProvider.overrideWith(
      (ref) => SettingsNotifier(
        ref.watch(settingsRepositoryProvider),
        AppSettings.defaults.copyWith(onboardingSeen: true),
      ),
    );
