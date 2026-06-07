import 'package:flutter/material.dart';

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
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.divider,
      splashFactory: InkSparkle.splashFactory,
      textTheme: AppTextTheme.materialTextTheme(colors.onSurface),
      extensions: <ThemeExtension<dynamic>>[colors],
      // Aura draws its own nav bar; suppress Material defaults that would
      // otherwise leak in.
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
