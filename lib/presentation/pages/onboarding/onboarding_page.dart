import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/aurora_colors.dart';
import '../../../core/constants/motion_tokens.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/press_scale.dart';
import 'onboarding_scenes.dart';

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

/// What each slide is for, and the scene that demonstrates it.
enum _Scene { pulse, glass, lyrics, equaliser }

class _Slide {
  const _Slide({
    required this.scene,
    required this.title,
    required this.body,
    required this.cta,
  });

  final _Scene scene;
  final String title;
  final String body;
  final String cta;
}

const _kSlides = [
  _Slide(
    scene: _Scene.pulse,
    title: 'Welcome to Aura',
    body:
        'A local-first player for the music you actually own. No ads, no cloud, '
        'no tracking — just your library, beautifully.',
    cta: 'Get started',
  ),
  _Slide(
    scene: _Scene.glass,
    title: 'Liquid Glass, on true black',
    body:
        'Surfaces blur and float over your artwork, and one calm accent is '
        'pulled from every album cover.',
    cta: 'Next',
  ),
  _Slide(
    scene: _Scene.lyrics,
    title: 'Lyrics that keep time',
    body:
        'Synced word by word, and paced across the track even when a song only '
        'ships plain text.',
    cta: 'Next',
  ),
  _Slide(
    scene: _Scene.equaliser,
    title: 'Sound you can shape',
    body:
        'A ten-band equaliser and a waveform you can scrub — tuned for the way '
        'you actually listen.',
    cta: 'Start listening',
  ),
];

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final _pages = PageController();
  int _slide = 0;

  // One slow drift for the backdrop, one faster loop the scenes read from, so
  // every demonstration stays in step with the others.
  late final AnimationController _backdrop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  late final AnimationController _scene = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    for (final c in [_backdrop, _scene]) {
      if (_reduceMotion) {
        c.stop();
      } else if (!c.isAnimating) {
        c.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _backdrop.dispose();
    _scene.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _next() {
    if (_slide >= _kSlides.length - 1) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: MotionTokens.screen,
      curve: MotionTokens.emphasized,
    );
  }

  Widget _sceneFor(_Scene scene) {
    switch (scene) {
      case _Scene.pulse:
        return AuraPulseScene(progress: _scene, reduceMotion: _reduceMotion);
      case _Scene.glass:
        return DynamicColourScene(
            progress: _scene, reduceMotion: _reduceMotion);
      case _Scene.lyrics:
        return SyncedLyricsScene(
            progress: _scene, reduceMotion: _reduceMotion);
      case _Scene.equaliser:
        return EqualiserScene(progress: _scene, reduceMotion: _reduceMotion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLast = _slide == _kSlides.length - 1;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AuroraBackdrop(
              progress: _backdrop,
              reduceMotion: _reduceMotion,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Swipeable, so the slides can be browsed both ways rather
                // than only pushed forward.
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _slide = i),
                    itemCount: _kSlides.length,
                    itemBuilder: (context, i) => _SlideView(
                      slide: _kSlides[i],
                      scene: _sceneFor(_kSlides[i].scene),
                    ),
                  ),
                ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(SpacingTokens.xxl,
                      SpacingTokens.lg, SpacingTokens.xxl, SpacingTokens.xl),
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
                          child: PressScale(
                            onTap: _next,
                            pressedScale: 0.96,
                            child: Center(
                              child: Text(
                                _kSlides[_slide].cta,
                                style: AppTextTheme.action
                                    .copyWith(color: AuroraColors.onAurora),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.xs),
                      // Kept in the layout when hidden so the button above
                      // doesn't jump on the last slide.
                      AnimatedOpacity(
                        opacity: isLast ? 0.0 : 1.0,
                        duration: MotionTokens.micro,
                        child: IgnorePointer(
                          ignoring: isLast,
                          child: TextButton(
                            onPressed: _finish,
                            child: Text(
                              'Skip',
                              style: AppTextTheme.body
                                  .copyWith(color: colors.onSurfaceMuted),
                            ),
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

/// One slide: the demonstration, then the words for it.
///
/// Scrollable so a long body at a large text scale can never overflow — the
/// old fixed Column with two Spacers had no give on short screens.
class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.scene});

  final _Slide slide;
  final Widget scene;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.xxl, vertical: SpacingTokens.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                scene,
                const SizedBox(height: SpacingTokens.xxl),
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: AppTextTheme.display.copyWith(
                    color: colors.onSurface,
                    fontSize: 29,
                    letterSpacing: -0.5,
                    height: 1.14,
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
    );
  }
}
