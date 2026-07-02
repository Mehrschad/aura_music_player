import 'package:flutter/material.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../artwork/aura_artwork.dart';
import 'now_playing_route.dart';

/// The Now Playing album art: a [Hero] (so it flies from the mini player) that
/// scales up to 1.08× while playing (with a gentle 1.015 breath on top) and
/// settles back to 0.94× when paused — iOS 26 artwork presence spec.
///
/// When [slideDirection] is non-zero the [AnimatedSwitcher] uses a directional
/// slide+fade instead of a plain crossfade: +1 → new art enters from the right
/// (skip-forward), -1 → from the left (skip-backward).
class BreathingArtwork extends StatefulWidget {
  const BreathingArtwork({
    super.key,
    required this.seed,
    required this.size,
    required this.playing,
    this.hasArtwork = false,
    this.artworkId,
    this.slideDirection = 0,
  });

  final String seed;
  final double size;
  final bool playing;
  final bool hasArtwork;
  final int? artworkId;

  /// +1 = skip-forward (new art enters from right),
  /// -1 = skip-backward (new art enters from left),
  ///  0 = plain crossfade (initial or no directional cue).
  final int slideDirection;

  @override
  State<BreathingArtwork> createState() => _BreathingArtworkState();
}

class _BreathingArtworkState extends State<BreathingArtwork>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;

  // A second, slower loop (deliberately not a multiple of the breath period)
  // drives a faint vertical drift. Two incommensurate periods layered together
  // read as organic — the motion never quite repeats — instead of a metronome.
  late final AnimationController _bobCtrl;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _pauseScale;
  late final Animation<double> _pauseRise;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(vsync: this, duration: MotionTokens.breathing);
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6700),
    );
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Playing = 1.08× (confident presence), paused = 0.94× (settled back).
    _pauseScale = Tween<double>(begin: 1.08, end: 0.94)
        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));
    // Artwork rises ~8 px when paused — reinforces the "resting" feel.
    _pauseRise = Tween<double>(begin: 0.0, end: -8.0)
        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));
    // Set the correct initial scale without animation.
    _scaleCtrl.value = widget.playing ? 0.0 : 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreathing();
  }

  @override
  void didUpdateWidget(BreathingArtwork old) {
    super.didUpdateWidget(old);
    if (widget.playing != old.playing) _syncBreathing();
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _bobCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _syncBreathing() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.playing && !reduceMotion) {
      _breathCtrl.repeat(reverse: true);
      _bobCtrl.repeat(reverse: true);
      _scaleCtrl.reverse(); // → 0.0 → _pauseScale = 1.0
    } else {
      _breathCtrl.stop();
      _breathCtrl.value = 0;
      _bobCtrl.stop();
      _bobCtrl.value = 0;
      if (reduceMotion) {
        _scaleCtrl.value = widget.playing ? 0.0 : 1.0;
      } else {
        _scaleCtrl.forward(); // → 1.0 → _pauseScale = 0.88
      }
    }
  }

  Widget _buildTransition(Widget child, Animation<double> anim) {
    final dir = widget.slideDirection;

    // No directional cue: plain crossfade (used for the initial artwork render
    // and any time the direction is unknown).
    if (dir == 0) {
      final eased = CurvedAnimation(parent: anim, curve: MotionTokens.standard);
      return FadeTransition(opacity: eased, child: child);
    }

    // anim goes 0→1 for the incoming child (status = forward / completed)
    // and 1→0 for the outgoing child (status = reverse / dismissed).
    final isIn = anim.status == AnimationStatus.forward ||
        anim.status == AnimationStatus.completed;

    if (isIn) {
      // New cover: glides in from the skip direction and settles into place
      // with a confident decelerating landing and a slight grow.
      final eased = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: eased,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(dir * 0.42, 0),
            end: Offset.zero,
          ).animate(eased),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(eased),
            child: child,
          ),
        ),
      );
    }

    // Old cover: accelerates out the opposite side, shrinking slightly as it
    // leaves so the incoming art clearly takes the stage.
    final eased = CurvedAnimation(parent: anim, curve: Curves.easeInCubic);
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(-dir * 0.42, 0),
          end: Offset.zero,
        ).animate(eased),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(eased),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A clearly perceptible inhale/exhale — sine-eased so the turnarounds are
    // soft, with the slower bob layered on top for an unmetronomic feel.
    final breatheScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOutSine),
    );
    final bob = Tween<double>(begin: 0.0, end: 3.0).animate(
      CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOutSine),
    );

    return Hero(
      tag: kNowPlayingHeroTag,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathCtrl, _bobCtrl, _scaleCtrl]),
        builder: (_, child) => Transform.translate(
          // Artwork floats up slightly when paused — matches light convergence.
          offset: Offset(0, _pauseRise.value + bob.value),
          child: Transform.scale(
            scale: breatheScale.value * _pauseScale.value,
            child: child,
          ),
        ),
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
          child: AnimatedSwitcher(
            // Plain linear parent; all easing is applied inside _buildTransition.
            duration: const Duration(milliseconds: 340),
            transitionBuilder: _buildTransition,
            child: AuraArtwork(
              key: ValueKey('${widget.seed}_${widget.artworkId}'),
              seed: widget.seed,
              size: widget.size,
              borderRadius: RadiusTokens.brLg,
              hasArtwork: widget.hasArtwork,
              artworkId: widget.artworkId,
            ),
          ),
        ),
      ),
    );
  }
}
