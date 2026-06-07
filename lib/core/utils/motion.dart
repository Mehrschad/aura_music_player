import 'package:flutter/widgets.dart';

/// Reduced-motion helpers. The OS "remove animations" accessibility setting
/// surfaces as `MediaQuery.disableAnimations`; honouring it everywhere keeps
/// Aura usable for people who are motion-sensitive.
extension MotionContext on BuildContext {
  /// True when the platform has asked apps to minimise motion.
  bool get animationsDisabled =>
      MediaQuery.maybeOf(this)?.disableAnimations ?? false;

  /// Collapses [base] to [Duration.zero] when animations are disabled, so
  /// transitions complete instantly instead of being removed entirely.
  Duration motion(Duration base) => animationsDisabled ? Duration.zero : base;
}
