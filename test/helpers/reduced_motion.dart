import 'package:flutter_test/flutter_test.dart';

/// Turns on the platform "disable animations" flag for the current test, and
/// clears it again on tear-down.
///
/// The app runs several deliberately endless animations — the search loading
/// shimmer, the now-playing bars, the waveform, the Now Playing ambient drift.
/// `pumpAndSettle` waits for the frame pipeline to go quiet, so any test that
/// mounts the shell while one of those loops would time out instead of
/// settling.
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
