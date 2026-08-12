import 'package:aura_music_player/core/l10n/app_localizations.dart';
import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:aura_music_player/presentation/pages/onboarding/onboarding_page.dart';
import 'package:aura_music_player/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reduced_motion.dart';

/// Mirrors how the shell opens the intro: pushed over the app, not the root
/// route — so finishing it pops back to something, as it does on device.
final _navKey = GlobalKey<NavigatorState>();

Widget _app() => ProviderScope(
      child: MaterialApp(
        navigatorKey: _navKey,
        theme: AppTheme.dark(flavor: DarkFlavor.amoled),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

Future<ProviderContainer> _open(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  final container =
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  openOnboarding(_navKey.currentContext!);
  await tester.pumpAndSettle();
  return container;
}

/// Phone sizes the intro has to survive, including a short one — the screen
/// previously laid itself out with two Spacers and no give, so a small display
/// pushed it into overflow.
const _sizes = <String, Size>{
  'compact 360x640': Size(360, 640),
  'tall 412x915': Size(412, 915),
};

void main() {
  group('onboarding', () {
    for (final entry in _sizes.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        useReducedMotion(tester);
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _open(tester);

        expect(find.text('Welcome to Aura'), findsOneWidget);
        // Overflow reports through the exception channel; the intro must stay
        // clean at every size it can be opened at.
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('walks every slide and records completion', (tester) async {
      useReducedMotion(tester);
      final container = await _open(tester);
      expect(container.read(settingsProvider).onboardingSeen, isFalse);

      // One call to action per slide; the last one finishes the flow.
      for (final cta in ['Get started', 'Next', 'Next', 'Start listening']) {
        expect(find.text(cta), findsOneWidget);
        await tester.tap(find.text(cta));
        await tester.pumpAndSettle();
      }

      expect(find.byType(OnboardingPage), findsNothing);
      expect(container.read(settingsProvider).onboardingSeen, isTrue,
          reason: 'finishing the intro must not leave it to reappear');
    });

    testWidgets('Skip finishes the flow from the first slide', (tester) async {
      useReducedMotion(tester);
      final container = await _open(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsNothing);
      expect(container.read(settingsProvider).onboardingSeen, isTrue);
    });
  });
}
