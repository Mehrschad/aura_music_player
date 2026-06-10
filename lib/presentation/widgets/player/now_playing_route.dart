import 'package:flutter/material.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../pages/now_playing/now_playing_page.dart';

/// Hero tag shared between the mini player artwork and the Now Playing artwork,
/// so the art flies between them on open/close. There is only ever one of each
/// on screen, so a constant tag is safe.
const String kNowPlayingHeroTag = 'now_playing_artwork';

/// Pushes the Now Playing screen with a slide-up + fade. The shared-element
/// artwork morph is handled automatically by the [Hero] widgets on both ends.
Future<void> openNowPlaying(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: context.motion(MotionTokens.screen),
      reverseTransitionDuration: context.motion(const Duration(milliseconds: 280)),
      opaque: true,
      pageBuilder: (_, __, ___) => const NowPlayingPage(),
      transitionsBuilder: (context, animation, _, child) {
        final enter = CurvedAnimation(
          parent: animation,
          curve: MotionTokens.emphasized,
          reverseCurve: MotionTokens.fastOut,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(enter),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(enter),
            child: child,
          ),
        );
      },
    ),
  );
}
