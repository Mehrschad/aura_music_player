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
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
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
