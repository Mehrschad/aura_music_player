import 'package:flutter/material.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../pages/now_playing/now_playing_page.dart';

/// Hero tag shared between the mini player artwork and the Now Playing artwork,
/// so the art flies between them on open/close.
const String kNowPlayingHeroTag = 'now_playing_artwork';

/// Pushes the Now Playing screen with a combined slide-up, fade, and scale
/// transition. The reverse (close) scales back down with a spring-like feel
/// so the page naturally "settles" back into the mini player.
Future<void> openNowPlaying(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: context.motion(MotionTokens.screen),
      reverseTransitionDuration:
          context.motion(const Duration(milliseconds: 320)),
      opaque: true,
      pageBuilder: (_, __, ___) => const NowPlayingPage(),
      transitionsBuilder: (context, animation, _, child) {
        final enter = CurvedAnimation(
          parent: animation,
          curve: MotionTokens.emphasized,
          reverseCurve: MotionTokens.fastOut,
        );
        // Open: slide up + fade in + slight scale from 0.94→1.0
        // Close: scale down to 0.94 + fade out + slide down
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(enter),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(enter),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(enter),
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
    ),
  );
}
