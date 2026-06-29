import 'package:flutter/material.dart';

import '../constants/radius_tokens.dart';
import 'color_scheme.dart';
import 'typography.dart';

/// Which dark flavour to build. AMOLED uses true black; standard dark uses
/// near-black surfaces for slightly softer contrast.
enum DarkFlavor { standard, amoled }

/// Builds Aura's [ThemeData]. Material is configured to recede — Aura's own
/// [AppColors] extension and [AppTextTheme] carry the real design language.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData dark({DarkFlavor flavor = DarkFlavor.amoled}) {
    final colors = flavor == DarkFlavor.amoled ? AppColors.amoled : AppColors.dark;
    return _build(brightness: Brightness.dark, colors: colors);
  }

  static ThemeData light() {
    return _build(brightness: Brightness.light, colors: AppColors.light);
  }

  static ThemeData _build({
    required Brightness brightness,
    required AppColors colors,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    ).copyWith(
      surface: colors.background,
      onSurface: colors.onSurface,
      primary: colors.accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTextTheme.fontFamily,
      colorScheme: scheme,
      // Transparent so the app-wide AuraAmbientBackground (a living, cover-
      // tinted gradient) shows through every screen. The ambient layer always
      // paints an opaque base, so nothing renders see-through.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: colors.background,
      dividerColor: colors.divider,
      splashFactory: NoSplash.splashFactory,
      textTheme: AppTextTheme.materialTextTheme(colors.onSurface),
      extensions: <ThemeExtension<dynamic>>[colors],
      // Aura draws its own nav bar; suppress Material defaults that would
      // otherwise leak in.
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
      ),
      // Floating snackbars on an elevated surface so they never collide with
      // the glass nav bar; one theme styles every call site.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surfaceElevated,
        contentTextStyle:
            AppTextTheme.body.copyWith(color: colors.onSurface),
        actionTextColor: colors.accent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: RadiusTokens.brMd),
      ),
      // Unifies every dialog's colour + corner radius (Material's default is
      // 28px; Aura uses brLg = 20).
      dialogTheme: DialogTheme(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: RadiusTokens.brLg),
        titleTextStyle: AppTextTheme.title.copyWith(color: colors.onSurface),
        contentTextStyle:
            AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
      ),
    );
  }
}
