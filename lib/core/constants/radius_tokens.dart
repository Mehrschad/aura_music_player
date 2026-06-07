import 'package:flutter/widgets.dart';

/// Corner radius scale. Album art, glass surfaces, and cards all draw
/// their roundedness from here so the language stays consistent.
abstract final class RadiusTokens {
  const RadiusTokens._();

  static const double xs = 8; // mini-player artwork
  static const double sm = 12; // compact rows, chips
  static const double md = 16; // cards, sheets
  static const double lg = 20; // now-playing album art
  static const double xl = 28; // floating glass nav bar
  static const double pill = 999; // fully rounded

  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);
  static const Radius rPill = Radius.circular(pill);

  static const BorderRadius brXs = BorderRadius.all(rXs);
  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
  static const BorderRadius brXl = BorderRadius.all(rXl);
  static const BorderRadius brPill = BorderRadius.all(rPill);
}
