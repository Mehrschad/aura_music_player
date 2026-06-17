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
  /// Smooth deceleration — for elements entering the screen (easeOutCubic).
  static const Curve standard = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Smooth in-out — for elements that move within the screen (easeInOutCubic).
  static const Curve emphasized = Cubic(0.65, 0.0, 0.35, 1.0);

  /// Fast start, gentle landing — for dismiss / exit transitions.
  static const Curve fastOut = Curves.easeIn;

  /// Gentle spring-like overshoot for satisfying pop-in effects.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Softer settle — a gentle landing with the slightest overshoot.
  static const Curve softSpring = Cubic(0.5, 1.25, 0.6, 1.0);
}
