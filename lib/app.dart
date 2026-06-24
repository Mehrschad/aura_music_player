import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/settings_providers.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/widgets/ambient/aura_ambient_background.dart';

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
          // The living gradient backdrop sits behind the whole navigator;
          // every (transparent) scaffold shows it through, and every glass
          // surface now blurs colour instead of flat black.
          child: Stack(
            children: [
              const Positioned.fill(child: AuraAmbientBackground()),
              child ?? const SizedBox.shrink(),
            ],
          ),
        );
      },
      home: const AppShell(),
    );
  }
}
