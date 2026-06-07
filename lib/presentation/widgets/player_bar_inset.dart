import 'package:flutter/widgets.dart';

import '../../core/constants/spacing_tokens.dart';

/// Shared mini-player geometry, referenced by both the mini player itself and
/// the scroll-inset calculation so they can never drift apart.
abstract final class MiniPlayerMetrics {
  const MiniPlayerMetrics._();

  /// Card height.
  static const double height = 64;

  /// Horizontal margin from the screen edges (matches the nav bar).
  static const double horizontalMargin = SpacingTokens.lg;

  /// Gap between the mini player and the nav bar below it.
  static const double gapToNavBar = SpacingTokens.sm;

  /// Total vertical space the mini player occupies above the nav bar.
  static const double reservedSpace = height + gapToNavBar;
}

/// Bottom padding a scroll view needs so its last item clears the floating
/// glass nav bar — and, when [miniPlayerVisible], the mini player stacked above
/// it. Centralised so every scrollable stays consistent.
double playerBarInset(BuildContext context, {bool miniPlayerVisible = false}) {
  const navBarHeight = 64.0;
  const navBarBottomMargin = SpacingTokens.lg; // matches GlassNavBar
  const breathingGap = SpacingTokens.lg;
  final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
  final base = navBarHeight + navBarBottomMargin + breathingGap + safeBottom;
  return base + (miniPlayerVisible ? MiniPlayerMetrics.reservedSpace : 0);
}
