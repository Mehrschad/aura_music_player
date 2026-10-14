import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/color_scheme.dart';
import 'presentation/providers/settings_providers.dart';
import 'presentation/shell/app_shell.dart';

/// Root widget. Theme, locale, density and text scale are driven by
/// [settingsProvider], so changes in Settings apply app-wide immediately.
class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final density = visualDensityFor(settings.density);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(visualDensity: density),
      darkTheme: AppTheme.dark(flavor: darkFlavorFor(settings.themePref))
          .copyWith(visualDensity: density),
      themeMode: themeModeFor(settings.themePref),
      locale: localeFor(settings.locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // RTL (fa, ar) mirrors the whole layout automatically via the locale.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // The OS text-size preference is the baseline; the in-app slider is a
        // multiplier on top of it, so someone who set a large system font keeps
        // it without having to find Aura's own control. This mirrors how
        // in-app Reduce Motion augments the OS flag just below, rather than
        // replacing it.
        //
        // Sampled at 16pt (the body size) because Android's system scaler is
        // non-linear above 1.0 and TextScaler.linear cannot carry that curve.
        // The clamp keeps the composed result inside a range dense layouts can
        // survive: 0.85 matches the slider's own floor, 2.0 is Android's
        // maximum accessibility scale.
        final systemScale = mq.textScaler.scale(16) / 16;
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(
              (systemScale * settings.textScale).clamp(0.85, 2.0).toDouble(),
            ),
            // In-app Reduce Motion augments the OS accessibility flag so
            // the user can suppress animations without changing system prefs.
            disableAnimations:
                settings.reduceMotion || mq.disableAnimations,
          ),
          // Flat, solid backdrop behind the whole navigator — pure AMOLED black
          // in the dark/amoled theme (paper-white in light). No gradient, no
          // living wash: every (transparent) scaffold shows this single colour.
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: context.colors.background),
              ),
              child ?? const SizedBox.shrink(),
            ],
          ),
        );
      },
      home: const AppShell(),
    );
  }
}
