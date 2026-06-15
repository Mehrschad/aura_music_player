import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../press_scale.dart';

/// The primary play/pause control: a filled circle with an [AnimatedIcon] that
/// morphs between play and pause. This is the one place the design allows a
/// bold, high-weight primary action, so it's a solid `onSurface` disc.
///
/// Honours `MediaQuery.disableAnimations` by jumping the morph instantly.
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionTokens.micro,
    value: widget.playing ? 1 : 0,
  );

  @override
  void didUpdateWidget(PlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final target = widget.playing ? 1.0 : 0.0;
    if (reduceMotion) {
      _controller.value = target;
    } else {
      _controller.animateTo(target, curve: MotionTokens.standard);
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
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      semanticLabel: widget.semanticLabel,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: colors.onSurface,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: _controller,
            size: widget.size * 0.44,
            color: colors.background,
          ),
        ),
      ),
    );
  }
}
