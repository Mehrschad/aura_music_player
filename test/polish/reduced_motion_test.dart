import 'package:aura_music_player/core/utils/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('context.motion collapses to zero when animations disabled',
      (tester) async {
    Duration? out;
    bool? disabledFlag;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Builder(builder: (c) {
        disabledFlag = c.animationsDisabled;
        out = c.motion(const Duration(milliseconds: 300));
        return const SizedBox();
      }),
    ));
    expect(disabledFlag, isTrue);
    expect(out, Duration.zero);
  });

  testWidgets('context.motion passes the duration through when enabled',
      (tester) async {
    Duration? out;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: false),
      child: Builder(builder: (c) {
        out = c.motion(const Duration(milliseconds: 300));
        return const SizedBox();
      }),
    ));
    expect(out, const Duration(milliseconds: 300));
  });
}
