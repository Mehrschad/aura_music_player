import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../press_scale.dart';

/// The primary play/pause control: a filled disc with an [AnimatedIcon] that
/// morphs between play and pause. On tap, concentric water-ripple rings expand
/// outward and fade. Simple, monochrome.
class PlayPauseButton extends StatefulWidget {
  const PlayPauseButton({
    super.key,
    required this.playing,
    required this.onTap,
    this.size = 72,
    this.semanticLabel,
  });

  final bool playing;
  final Future<void> Function() onTap;
  final double size;
  final String? semanticLabel;

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
    with TickerProviderStateMixin {
  late final AnimationController _morphCtrl = AnimationController(
    vsync: this,
    duration: MotionTokens.micro,
    value: widget.playing ? 1 : 0,
  );

  // Drives two staggered ripple rings on each tap.
  late final AnimationController _rippleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void didUpdateWidget(PlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final target = widget.playing ? 1.0 : 0.0;
    if (reduceMotion) {
      _morphCtrl.value = target;
    } else {
      _morphCtrl.animateTo(target, curve: MotionTokens.standard);
    }
  }

  @override
  void dispose() {
    _morphCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        _rippleCtrl.forward(from: 0);
        widget.onTap();
      },
      semanticLabel: widget.semanticLabel,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_morphCtrl, _rippleCtrl]),
          builder: (_, __) {
            final t = _rippleCtrl.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                _rippleRing(colors.accent, t, delay: 0.00),
                _rippleRing(colors.accent, t, delay: 0.15),
                // Teal-filled disc: the single bold accent in the product.
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(colors.accent, Colors.white, 0.18)!,
                        colors.accent,
                        Color.lerp(colors.accent, Colors.black, 0.14)!,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.22),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withOpacity(0.38),
                        blurRadius: 22,
                        spreadRadius: -3,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _morphCtrl,
                    size: widget.size * 0.44,
                    color: colors.onAccent,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rippleRing(Color color, double t, {required double delay}) {
    final adjT =
        math.max(0.0, (t - delay) / math.max(0.001, 1.0 - delay)).clamp(0.0, 1.0);
    final scale = 1.0 + 1.45 * Curves.easeOut.transform(adjT);
    final opacity = 0.38 * (1.0 - Curves.easeIn.transform(adjT));
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
      ),
    );
  }
}
