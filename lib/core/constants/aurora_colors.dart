import 'package:flutter/material.dart';

/// The Aura signature aurora palette — Aura's bottled colour for delight
/// moments: the logo, onboarding, the play-button disc when playing, and
/// empty-state icons. Used with surgical restraint. The product stays calm
/// and monochrome; aurora is the moment of joy.
abstract final class AuroraColors {
  const AuroraColors._();

  static const Color c1 = Color(0xFF5EE7C8); // teal-mint
  static const Color c2 = Color(0xFF4AA8FF); // sky blue
  static const Color c3 = Color(0xFF9A7BFF); // violet
  static const Color c4 = Color(0xFFFF8FD0); // soft magenta

  /// Dark text / icon colour for rendering ON an aurora-filled surface.
  static const Color onAurora = Color(0xFF07131A);

  /// The full 4-stop aurora ribbon at 115° — teal → blue → violet → magenta.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment(-0.9, -0.7),
    end: Alignment(0.9, 0.7),
    stops: [0.0, 0.38, 0.72, 1.0],
    colors: [c1, c2, c3, c4],
  );

  /// A softer 3-stop aurora at 70% opacity — for icon masks and subtle fills.
  static const LinearGradient gradientSoft = LinearGradient(
    begin: Alignment(-0.9, -0.7),
    end: Alignment(0.9, 0.7),
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color(0xB35EE7C8), // c1 at 70%
      Color(0xB39A7BFF), // c3 at 70%
      Color(0xB3FF8FD0), // c4 at 70%
    ],
  );
}
