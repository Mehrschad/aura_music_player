import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import 'glass_surface.dart';

/// A centred grab-handle for the top of a modal sheet. Gives every glass sheet
/// the same "pull to dismiss" affordance.
class SheetGrabHandle extends StatelessWidget {
  const SheetGrabHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SpacingTokens.xxxl,
      height: SpacingTokens.xs,
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      decoration: BoxDecoration(
        color: context.colors.onSurfaceFaint,
        borderRadius: RadiusTokens.brPill,
      ),
    );
  }
}

/// Shows [child] inside Aura's standard frosted glass bottom sheet: a
/// transparent barrier, a [GlassSurface] card inset from the screen edges, and
/// a [SheetGrabHandle] at the top. Centralises the sheet chrome so every sheet
/// looks and behaves identically.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = true,
  EdgeInsetsGeometry padding =
      const EdgeInsets.fromLTRB(0, SpacingTokens.sm, 0, 0),
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: (_) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrabHandle(),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
