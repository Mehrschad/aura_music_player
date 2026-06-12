import 'package:flutter/material.dart';

import '../../../core/utils/motion.dart';
import '../../pages/now_playing/now_playing_page.dart';

/// Hero tag shared between the mini player artwork and the Now Playing artwork,
/// so the art flies between them on open/close.
const String kNowPlayingHeroTag = 'now_playing_artwork';

/// Pushes the Now Playing screen with a long, buttery slide-up + fade + scale.
///
/// The open glides in on a deep ease-out so it feels weighty and smooth; the
/// close runs faster on an ease-in so the page "drops" back down — the mini
/// player then catches it with an elastic bounce, completing the sense that the
/// page was released from the force that held it open.
///
/// Any focused text field (e.g. the Search box) is dropped before we push, so
/// the soft keyboard isn't restored — and re-shown — when we return.
Future<void> openNowPlaying(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: context.motion(const Duration(milliseconds: 460)),
      reverseTransitionDuration:
          context.motion(const Duration(milliseconds: 300)),
      opaque: true,
      pageBuilder: (_, __, ___) => const NowPlayingPage(),
      transitionsBuilder: (context, animation, _, child) {
        // Deep, smooth deceleration opening; quick ease-in on the way out.
        final eased = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.16, 1.0, 0.3, 1.0), // expressive ease-out
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7),
              reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeIn),
            ),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.10),
              end: Offset.zero,
            ).animate(eased),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(eased),
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
    ),
  );
}
