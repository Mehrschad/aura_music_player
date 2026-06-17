import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/aurora_colors.dart';
import '../../../core/constants/motion_tokens.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../providers/settings_providers.dart';

void openOnboarding(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, __, ___) => const OnboardingPage(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: MotionTokens.screen,
    ),
  );
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  int _slide = 0;
  bool _visible = true;

  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  late final AnimationController _rippleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _bgCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_slide < _kSlides.length - 1) {
      setState(() => _visible = false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _slide++;
        _visible = true;
      });
    } else {
      await ref.read(settingsProvider.notifier).setOnboardingSeen();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final slide = _kSlides[_slide];

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => Transform.rotate(
                angle: reduceMotion ? 0 : _bgCtrl.value * 2 * math.pi * 0.25,
                child: Transform.scale(
                  scale: 1.4,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: AuroraColors.gradient,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.7),
                  radius: 1.2,
                  colors: [Colors.transparent, colors.background],
                  stops: const [0.3, 0.9],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                AnimatedOpacity(
                  opacity: _visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedSlide(
                    offset: _visible ? Offset.zero : const Offset(0, 0.08),
                    duration: const Duration(milliseconds: 320),
                    curve: MotionTokens.spring,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.xxxl),
                      child: Column(
                        children: [
                          if (_slide == 0)
                            _RippleMark(
                                ctrl: _rippleCtrl,
                                reduceMotion: reduceMotion)
                          else
                            _GlassIcon(icon: slide.icon!),
                          const SizedBox(height: SpacingTokens.xxl),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: AppTextTheme.display.copyWith(
                              color: colors.onSurface,
                              fontSize: 30,
                              letterSpacing: -0.5,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.md),
                          Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: AppTextTheme.body.copyWith(
                              color: colors.onSurfaceMuted,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: SpacingTokens.huge),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _kSlides.length; i++)
                      AnimatedContainer(
                        duration: MotionTokens.micro,
                        curve: MotionTokens.spring,
                        width: i == _slide ? 22 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _slide
                              ? colors.onSurface
                              : colors.onSurfaceFaint,
                          borderRadius: RadiusTokens.brPill,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(SpacingTokens.xxl, 0,
                      SpacingTokens.xxl, SpacingTokens.huge),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AuroraColors.gradient,
                            borderRadius: RadiusTokens.brPill,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4D4AA8FF),
                                blurRadius: 30,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: RadiusTokens.brPill,
                              onTap: _next,
                              child: Center(
                                child: Text(
                                  slide.cta,
                                  style: AppTextTheme.action.copyWith(
                                    color: AuroraColors.onAurora,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      AnimatedOpacity(
                        opacity: _slide < _kSlides.length - 1 ? 1.0 : 0.0,
                        duration: MotionTokens.micro,
                        child: TextButton(
                          onPressed: _slide < _kSlides.length - 1
                              ? () async {
                                  await ref
                                      .read(settingsProvider.notifier)
                                      .setOnboardingSeen();
                                  if (!mounted) return;
                                  Navigator.of(context).pop();
                                }
                              : null,
                          child: Text(
                            'Skip',
                            style: AppTextTheme.body
                                .copyWith(color: colors.onSurfaceMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RippleMark extends StatelessWidget {
  const _RippleMark({required this.ctrl, required this.reduceMotion});
  final AnimationController ctrl;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!reduceMotion)
            for (var i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) {
                  final phase = ((ctrl.value + i * 0.33) % 1.0);
                  return Opacity(
                    opacity: (1 - phase).clamp(0.0, 0.55),
                    child: Transform.scale(
                      scale: 0.6 + phase * 1.2,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AuroraColors.c2,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ShaderMask(
            shaderCallback: (b) => AuroraColors.gradient.createShader(b),
            blendMode: BlendMode.srcIn,
            child: CustomPaint(
              size: const Size(120, 120),
              painter: _MarkPainter120(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkPainter120 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final fill = Paint()..color = Colors.white;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(Offset(cx, cy), 6, fill);
    canvas.drawCircle(
        Offset(cx, cy), 17, ring..color = Colors.white.withOpacity(0.92));
    canvas.drawCircle(
        Offset(cx, cy), 29, ring..color = Colors.white.withOpacity(0.55));
    canvas.drawCircle(
        Offset(cx, cy), 41, ring..color = Colors.white.withOpacity(0.24));
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: colors.glassTint,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Icon(icon, size: 44, color: colors.onSurface),
    );
  }
}

const _kSlides = [
  _Slide(
    title: 'Welcome to Aura',
    body:
        'A local-first player for the music you actually own. No ads, no cloud, no tracking — just your library, beautifully.',
    cta: 'Get started',
  ),
  _Slide(
    icon: Icons.blur_on,
    title: 'Liquid Glass, on true black',
    body: 'Surfaces blur and float over your artwork. Dynamic colour pulls one calm accent from every album cover.',
    cta: 'Next',
  ),
  _Slide(
    icon: Icons.lyrics,
    title: 'Sing along, in sync',
    body: 'Word-by-word synced lyrics, a waveform you can scrub, and a 10-band EQ — all tuned for the way you listen.',
    cta: 'Start listening',
  ),
];

class _Slide {
  const _Slide(
      {required this.title,
      required this.body,
      required this.cta,
      this.icon});
  final String title;
  final String body;
  final String cta;
  final IconData? icon;
}
