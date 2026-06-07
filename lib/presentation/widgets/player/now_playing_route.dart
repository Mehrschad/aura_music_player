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
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: context.motion(MotionTokens.screen),
      reverseTransitionDuration: context.motion(MotionTokens.screen),
      opaque: false,
      pageBuilder: (_, __, ___) => const NowPlayingPage(),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: MotionTokens.standard,
          reverseCurve: MotionTokens.standard,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
