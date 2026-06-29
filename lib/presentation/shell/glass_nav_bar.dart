import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/motion_tokens.dart';
import '../../core/constants/radius_tokens.dart';
import '../../core/constants/spacing_tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/color_scheme.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/utils/seed_color.dart';
import '../providers/cover_palette_provider.dart';
import '../providers/playback_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/glass/glass_surface.dart';
import 'nav_provider.dart';

/// The floating Liquid-Glass navigation, iOS 26 style: the four primary tabs
/// live in a glass pill, Search sits in its own circular glass bubble beside
/// it. While the user scrolls down through content the whole bar fades out and
/// collapses away (the mini player above it then drops to the bottom edge);
/// scrolling back up brings it smoothly back.
///
/// Liquid drag gesture: long-press (~500 ms) anywhere on the main pill →
/// a ripple wave spawns → drag horizontally to stretch the selection capsule
/// across tabs → release to commit. Haptic tick on each tab boundary crossed.
class GlassNavBar extends ConsumerStatefulWidget {
  const GlassNavBar({super.key});

  @override
  ConsumerState<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends ConsumerState<GlassNavBar>
    with TickerProviderStateMixin {
  late final AnimationController _hide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _hide, curve: Curves.easeInOutCubic);

  // Ripple that fires when the liquid drag is recognised.
  late final AnimationController _rippleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  // Liquid-drag state.
  bool _liquidActive = false;
  double _liquidX = 0; // current finger X within the main-pill coordinate space
  int _liquidTargetIdx = 0; // which tab index the finger is over
  // Cached item width — updated on every LayoutBuilder pass, read from
  // gesture callbacks (which run outside the builder closure).
  double _itemWidth = 0;

  static const List<TabSpec> _mainTabs = [
    TabSpec(AppTab.library, Icons.library_music_outlined, Icons.library_music),
    TabSpec(AppTab.artists, Icons.person_outline, Icons.person),
    TabSpec(AppTab.albums, Icons.album_outlined, Icons.album),
    TabSpec(AppTab.playlists, Icons.queue_music_outlined, Icons.queue_music),
  ];

  @override
  void dispose() {
    _hide.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _selectTab(AppTab tab) {
    HapticFeedback.selectionClick();
    ref.read(selectedTabProvider.notifier).state = tab;
  }

  // ── Liquid drag callbacks ─────────────────────────────────────────────────

  void _onLiquidStart(LongPressStartDetails d) {
    HapticFeedback.mediumImpact();
    _rippleCtrl.forward(from: 0);
    final w = _itemWidth.clamp(1.0, double.infinity);
    setState(() {
      _liquidActive = true;
      _liquidX = d.localPosition.dx;
      _liquidTargetIdx = (d.localPosition.dx / w)
          .clamp(0.0, (_mainTabs.length - 1).toDouble())
          .round()
          .toInt();
    });
  }

  void _onLiquidMove(LongPressMoveUpdateDetails d) {
    if (_itemWidth <= 0) return;
    final newIdx = (d.localPosition.dx / _itemWidth)
        .clamp(0.0, (_mainTabs.length - 1).toDouble())
        .round()
        .toInt();
    if (newIdx != _liquidTargetIdx) HapticFeedback.selectionClick();
    setState(() {
      _liquidX = d.localPosition.dx;
      _liquidTargetIdx = newIdx;
    });
  }

  void _onLiquidEnd(LongPressEndDetails d) {
    if (_liquidTargetIdx >= 0 && _liquidTargetIdx < _mainTabs.length) {
      _selectTab(_mainTabs[_liquidTargetIdx].tab);
    }
    setState(() => _liquidActive = false);
  }

  void _onLiquidCancel() => setState(() => _liquidActive = false);

  // ── Label helpers ─────────────────────────────────────────────────────────

  String _labelFor(AppTab tab, AppLocalizations l10n) => switch (tab) {
        AppTab.library => l10n.tabLibrary,
        AppTab.artists => l10n.tabArtists,
        AppTab.albums => l10n.tabAlbums,
        AppTab.playlists => l10n.tabPlaylists,
        AppTab.search => l10n.tabSearch,
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTabProvider);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final intensity = ref.watch(settingsProvider.select((s) => s.glassIntensity));
    final colors = context.colors;

    ref.listen<bool>(navMinimizedProvider, (_, next) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _hide.value = next ? 1.0 : 0.0;
      } else if (next) {
        _hide.forward();
      } else {
        _hide.reverse();
      }
    });

    final song = ref.watch(currentSongProvider);
    final trackAccent = song == null
        ? null
        : ref
            .watch(coverPaletteProvider((
              seed: song.artworkSeed,
              hasArtwork: song.hasArtwork,
              artworkId: int.tryParse(song.id),
            )))
            .valueOrNull
            ?.accent;

    const barHeight = 58.0;
    final mainIndex = _mainTabs.indexWhere((t) => t.tab == selected);

    final bar = Padding(
      padding: EdgeInsets.only(
        left: SpacingTokens.lg,
        right: SpacingTokens.lg,
        bottom: SpacingTokens.lg + bottomInset,
      ),
      child: Row(
        children: [
          // ── Main pill: four primary tabs ──────────────────────────────────
          Expanded(
            child: GlassSurface(
              borderRadius: RadiusTokens.brPill,
              intensity: intensity,
              child: SizedBox(
                height: barHeight,
                child: GestureDetector(
                  // Long-press + drag to liquid-switch tabs.
                  onLongPressStart: _onLiquidStart,
                  onLongPressMoveUpdate: _onLiquidMove,
                  onLongPressEnd: _onLiquidEnd,
                  onLongPressCancel: _onLiquidCancel,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Cache item width so gesture callbacks can use it.
                      _itemWidth = constraints.maxWidth / _mainTabs.length;
                      final pillWidth = _itemWidth - 14;
                      const pillHeight = barHeight - 18;

                      final srcIdx = mainIndex < 0 ? 0 : mainIndex;
                      final pillLeft =
                          srcIdx * _itemWidth + (_itemWidth - pillWidth) / 2;

                      // During liquid drag the pill stretches to cover
                      // source → target, giving a satisfying elastic pull.
                      final double effectivePillLeft;
                      final double effectivePillWidth;
                      if (_liquidActive) {
                        final srcLeft = srcIdx * _itemWidth +
                            (_itemWidth - pillWidth) / 2;
                        final dstLeft = _liquidTargetIdx * _itemWidth +
                            (_itemWidth - pillWidth) / 2;
                        final leftmost =
                            srcLeft < dstLeft ? srcLeft : dstLeft;
                        final rightmost =
                            (srcLeft + pillWidth) > (dstLeft + pillWidth)
                                ? (srcLeft + pillWidth)
                                : (dstLeft + pillWidth);
                        effectivePillLeft = leftmost;
                        effectivePillWidth = rightmost - leftmost;
                      } else {
                        effectivePillLeft = pillLeft;
                        effectivePillWidth = pillWidth;
                      }

                      return Stack(
                        children: [
                          // Glossy selected capsule — always pill-shaped via
                          // AnimatedContainer.decoration (BoxDecoration.lerp).
                          AnimatedPositionedDirectional(
                            duration: _liquidActive
                                ? Duration.zero
                                : MotionTokens.screen,
                            curve: MotionTokens.spring,
                            start: effectivePillLeft,
                            top: (barHeight - pillHeight) / 2,
                            width: effectivePillWidth,
                            height: pillHeight,
                            child: AnimatedOpacity(
                              duration: MotionTokens.micro,
                              // Visible when a main tab is active OR during
                              // liquid drag (even when starting from Search).
                              opacity: (mainIndex >= 0 || _liquidActive)
                                  ? 1.0
                                  : 0.0,
                              child: _GlossyPill(
                                colors: colors,
                                accent: trackAccent,
                              ),
                            ),
                          ),
                          // Tab icons — during drag the target tab previews
                          // as "selected" so the icon lifts before commit.
                          Row(
                            children: [
                              for (final spec in _mainTabs)
                                SizedBox(
                                  width: _itemWidth,
                                  child: _NavItem(
                                    spec: spec,
                                    label: _labelFor(spec.tab, l10n),
                                    selected: _liquidActive
                                        ? spec.tab ==
                                            _mainTabs[_liquidTargetIdx].tab
                                        : spec.tab == selected,
                                    onTap: () => _selectTab(spec.tab),
                                  ),
                                ),
                            ],
                          ),
                          // Liquid spawn ripple — brief expanding ring that
                          // confirms the long-press was recognised.
                          if (_liquidActive)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _rippleCtrl,
                                  builder: (_, __) => CustomPaint(
                                    painter: _LiquidRipplePainter(
                                      localX: _liquidX.clamp(
                                          0.0, constraints.maxWidth),
                                      barHeight: barHeight,
                                      progress: _rippleCtrl.value,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          // ── Separate circular Search bubble (iOS 26 signature) ────────────
          _SearchBubble(
            label: _labelFor(AppTab.search, l10n),
            selected: selected == AppTab.search,
            intensity: intensity,
            size: barHeight,
            accent: trackAccent,
            onTap: () => _selectTab(AppTab.search),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final reveal = (1.0 - _t.value).clamp(0.0, 1.0);
        if (reveal <= 0.001) return const SizedBox(width: double.infinity);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: reveal,
            child: Opacity(
              opacity: reveal,
              child: Transform.translate(
                offset: Offset(0, _t.value * 28),
                child: child,
              ),
            ),
          ),
        );
      },
      child: bar,
    );
  }
}

/// The glossy selected-tab capsule.
///
/// Uses [AnimatedContainer] so the entire [BoxDecoration] — gradient, border,
/// and box shadow — animates via [BoxDecoration.lerp]. This keeps
/// [borderRadius] equal to [RadiusTokens.brPill] at **every** animation frame,
/// eliminating the rectangular-glow glitch that appeared when [TweenAnimationBuilder]
/// toggled the `hasColor` branch mid-transition (which previously split the
/// decoration into independently animated parts).
class _GlossyPill extends StatelessWidget {
  const _GlossyPill({required this.colors, this.accent});
  final AppColors colors;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: RadiusTokens.brPill,
        gradient: c != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.withOpacity(isDark ? 0.55 : 0.45),
                  c.withOpacity(isDark ? 0.30 : 0.20),
                ],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.onSurface.withOpacity(0.16),
                  colors.onSurface.withOpacity(0.07),
                ],
              ),
        border: Border.all(
          color: c != null
              ? c.withOpacity(0.45)
              : Colors.white.withOpacity(0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: c != null
                ? c.withOpacity(isDark ? 0.40 : 0.25)
                : Colors.white.withOpacity(0.05),
            blurRadius: c != null ? 12.0 : 6.0,
            spreadRadius: -2.0,
          ),
        ],
      ),
    );
  }
}

/// Expanding-ring ripple that plays once when the liquid drag is recognised.
class _LiquidRipplePainter extends CustomPainter {
  const _LiquidRipplePainter({
    required this.localX,
    required this.barHeight,
    required this.progress,
  });
  final double localX;
  final double barHeight;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    final center = Offset(localX, barHeight / 2);
    // Outer ring
    final radius = 30.0 * Curves.easeOut.transform(progress);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity((1.0 - progress) * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Inner ring — offset by 20 % so it trails behind the outer
    if (progress > 0.20) {
      final p2 = ((progress - 0.20) / 0.80).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        18.0 * Curves.easeOut.transform(p2),
        Paint()
          ..color = Colors.white.withOpacity((1.0 - p2) * 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(_LiquidRipplePainter o) =>
      o.localX != localX || o.progress != progress;
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.spec,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TabSpec spec;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = widget.selected ? colors.accent : colors.onSurfaceFaint;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.86 : 1.0,
          duration: MotionTokens.press,
          curve: MotionTokens.standard,
          child: SizedBox(
            height: 58,
            child: Center(
              child: AnimatedSwitcher(
                duration: MotionTokens.micro,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  widget.selected ? widget.spec.activeIcon : widget.spec.icon,
                  key: ValueKey(widget.selected),
                  size: 26,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The standalone circular Search bubble.
class _SearchBubble extends StatefulWidget {
  const _SearchBubble({
    required this.label,
    required this.selected,
    required this.intensity,
    required this.size,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final GlassIntensity intensity;
  final double size;
  final VoidCallback onTap;
  final Color? accent;

  @override
  State<_SearchBubble> createState() => _SearchBubbleState();
}

class _SearchBubbleState extends State<_SearchBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = widget.size;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: MotionTokens.press,
          curve: MotionTokens.standard,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(size / 2),
            intensity: widget.intensity,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.selected)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.accent != null
                              ? RadialGradient(
                                  colors: [
                                    widget.accent!.withOpacity(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? 0.55
                                            : 0.45),
                                    widget.accent!.withOpacity(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? 0.30
                                            : 0.20),
                                  ],
                                )
                              : RadialGradient(
                                  colors: [
                                    colors.onSurface.withOpacity(0.16),
                                    colors.onSurface.withOpacity(0.07),
                                  ],
                                ),
                          border: Border.all(
                            color: widget.accent != null
                                ? widget.accent!.withOpacity(0.45)
                                : Colors.white.withOpacity(0.12),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  Icon(
                    Icons.search,
                    size: 24,
                    color: widget.selected
                        ? colors.onSurface
                        : colors.onSurfaceFaint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
