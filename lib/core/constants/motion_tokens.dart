import 'package:flutter/animation.dart';

/// Motion language for Aura. "Motion that breathes" — every transition
/// reads from here so timing and easing stay disciplined across the app.
abstract final class MotionTokens {
  const MotionTokens._();

  // ── Durations ──────────────────────────────────────────────────────────
  /// Micro-interactions: button press feedback, toggles.
  static const Duration micro = Duration(milliseconds: 220);

  /// Press-and-spring-back for tappable controls.
  static const Duration press = Duration(milliseconds: 160);

  /// Screen / route transitions.
  static const Duration screen = Duration(milliseconds: 380);

  /// Album art morph / hero crossfade between tracks.
  static const Duration albumArt = Duration(milliseconds: 500);

  /// The barely-perceptible "breathing" loop on playing album art.
  static const Duration breathing = Duration(seconds: 4);

  // ── Curves ─────────────────────────────────────────────────────────────
  /// Default for things entering or settling.
  static const Curve standard = Curves.easeOutCubic;

  /// Default for things that move and come to rest in place.
  static const Curve emphasized = Curves.easeInOutCubic;
}
