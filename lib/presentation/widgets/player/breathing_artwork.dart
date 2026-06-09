import 'package:flutter/material.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../artwork/aura_artwork.dart';
import 'now_playing_route.dart';

/// The Now Playing album art: a [Hero] (so it flies from the mini player) that
/// breathes — scaling 1.0 → 1.015 → 1.0 on a 4-second loop — while playing.
/// The motion is deliberately at the edge of perception, and collapses to a
/// still image when paused or when animations are disabled.
class BreathingArtwork extends StatefulWidget {
  const BreathingArtwork({
    super.key,
    required this.seed,
    required this.size,
    required this.playing,
    this.hasArtwork = false,
  });

  final String seed;
  final double size;
  final bool playing;
  final bool hasArtwork;

  @override
  State<BreathingArtwork> createState() => _BreathingArtworkState();
}

class _BreathingArtworkState extends State<BreathingArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionTokens.breathing,
  );

  @override
  void initState() {
    super.initState();
    // _syncBreathing is deferred to didChangeDependencies because
    // MediaQuery.disableAnimationsOf(context) must not be called before
    // initState completes.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreathing();
  }

  @override
  void didUpdateWidget(BreathingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) _syncBreathing();
  }

  void _syncBreathing() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.playing && !reduceMotion) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Tween<double>(begin: 1, end: 1.015)
        .animate(CurvedAnimation(parent: _controller, curve: MotionTokens.emphasized));

    return Hero(
      tag: kNowPlayingHeroTag,
      child: ScaleTransition(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: RadiusTokens.brLg,
            boxShadow: [
              BoxShadow(
                color: colors.scrim,
                blurRadius: 48,
                spreadRadius: 4,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: AuraArtwork(
            seed: widget.seed,
            size: widget.size,
            borderRadius: RadiusTokens.brLg,
            hasArtwork: widget.hasArtwork,
          ),
        ),
      ),
    );
  }
}
