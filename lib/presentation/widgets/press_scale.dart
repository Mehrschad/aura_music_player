import 'package:flutter/material.dart';

import '../../core/constants/motion_tokens.dart';

/// Wraps a tappable child with Aura's standard press feedback: scale to 0.92 on
/// press and spring back over 160ms. Respects `MediaQuery.disableAnimations`
/// (collapses to no scale). Keeps the gesture/scale logic in one place so every
/// tappable surface feels identical.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.pressedScale = 0.92,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Optional long-press handler (e.g. enter multi-select). When set, the
  /// gesture also exposes a Semantics long-press action.
  final VoidCallback? onLongPress;
  final double pressedScale;
  final String? semanticLabel;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = (_down && !reduceMotion) ? widget.pressedScale : 1.0;

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      onLongPress: widget.onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: scale,
          duration: reduceMotion ? Duration.zero : MotionTokens.press,
          curve: MotionTokens.standard,
          child: widget.child,
        ),
      ),
    );
  }
}
