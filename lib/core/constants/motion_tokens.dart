import 'package:flutter/animation.dart';

/// Motion language for Aura. "Motion that breathes" — every transition
/// reads from here so timing and easing stay disciplined across the app.
abstract final class MotionTokens {
  const MotionTokens._();

  // ── Durations ──────────────────────────────────────────────────────────
  /// Micro-interactions: button press feedback, toggles.
  static const Duration micro = Duration(milliseconds: 200);

  /// Press-and-spring-back for tappable controls.
  static const Duration press = Duration(milliseconds: 140);

  /// Screen / route transitions.
  static const Duration screen = Duration(milliseconds: 360);

  /// Album art morph / hero crossfade between tracks.
  static const Duration albumArt = Duration(milliseconds: 480);

  /// The barely-perceptible "breathing" loop on playing album art.
  static const Duration breathing = Duration(seconds: 4);

  // ── Curves ─────────────────────────────────────────────────────────────
  /// Smooth deceleration — for elements entering the screen.
  static const Curve standard = Curves.easeOutCubic;

  /// Smooth in-out — for elements that move within the screen.
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Fast start, gentle landing — for dismiss / exit transitions.
  static const Curve fastOut = Curves.easeIn;

  /// Gentle spring-like overshoot for satisfying pop-in effects.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);
}
