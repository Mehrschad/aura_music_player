import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/motion_tokens.dart';
import '../../core/constants/radius_tokens.dart';
import '../../core/constants/spacing_tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/color_scheme.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/theme/typography.dart';
import '../widgets/glass/glass_surface.dart';
import '../providers/settings_providers.dart';
import 'nav_provider.dart';

/// The floating Liquid-Glass navigation, iOS 26 style: the four primary tabs
/// live in a glass pill, Search sits in its own circular glass bubble beside
/// it. While the user scrolls down through content the whole bar fades out and
/// collapses away (the mini player above it then drops to the bottom edge);
/// scrolling back up brings it smoothly back.
class GlassNavBar extends ConsumerStatefulWidget {
  const GlassNavBar({super.key});

  @override
  ConsumerState<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends ConsumerState<GlassNavBar>
    with SingleTickerProviderStateMixin {
  /// 0 = fully shown (expanded), 1 = fully hidden (collapsed + faded).
  late final AnimationController _hide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _hide, curve: Curves.easeInOutCubic);

  /// Primary tabs in the main pill. Search is intentionally excluded — it gets
  /// its own bubble, mirroring the iOS 26 Music / App Store layout.
  static const List<TabSpec> _mainTabs = [
    TabSpec(AppTab.library, Icons.library_music_outlined, Icons.library_music),
    TabSpec(AppTab.artists, Icons.person_outline, Icons.person),
    TabSpec(AppTab.albums, Icons.album_outlined, Icons.album),
    TabSpec(AppTab.playlists, Icons.queue_music_outlined, Icons.queue_music),
  ];

  @override
  void dispose() {
    _hide.dispose();
    super.dispose();
  }

  String _labelFor(AppTab tab, AppLocalizations l10n) => switch (tab) {
        AppTab.library => l10n.tabLibrary,
        AppTab.artists => l10n.tabArtists,
        AppTab.albums => l10n.tabAlbums,
        AppTab.playlists => l10n.tabPlaylists,
        AppTab.search => l10n.tabSearch,
      };

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTabProvider);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final intensity = ref.watch(settingsProvider.select((s) => s.glassIntensity));
    final colors = context.colors;

    // Drive the hide/show animation off the scroll-minimize signal.
    ref.listen<bool>(navMinimizedProvider, (_, next) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _hide.value = next ? 1.0 : 0.0;
      } else if (next) {
        _hide.forward();
      } else {
        _hide.reverse();
      }
    });

    const barHeight = 64.0;
    final mainIndex = _mainTabs.indexWhere((t) => t.tab == selected);

    void selectTab(AppTab tab) {
      HapticFeedback.selectionClick();
      ref.read(selectedTabProvider.notifier).state = tab;
    }

    final bar = Padding(
      padding: EdgeInsets.only(
        left: SpacingTokens.lg,
        right: SpacingTokens.lg,
        bottom: SpacingTokens.lg + bottomInset,
      ),
      child: Row(
        children: [
          // ── Main pill: the four primary tabs ──────────────────────────────
          Expanded(
            child: GlassSurface(
              borderRadius: RadiusTokens.brPill,
              intensity: intensity,
              child: SizedBox(
                height: barHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / _mainTabs.length;
                    final pillWidth = itemWidth - 14;
                    const pillHeight = barHeight - 18;
                    final pillLeft = (mainIndex < 0 ? 0 : mainIndex) * itemWidth +
                        (itemWidth - pillWidth) / 2;

                    return Stack(
                      children: [
                        // Glossy selected capsule. Positioned by `start` so it
                        // mirrors correctly in RTL (fa/ar). Fades out when the
                        // Search bubble owns the selection instead.
                        AnimatedPositionedDirectional(
                          duration: MotionTokens.screen,
                          curve: MotionTokens.spring,
                          start: pillLeft,
                          top: (barHeight - pillHeight) / 2,
                          width: pillWidth,
                          height: pillHeight,
                          child: AnimatedOpacity(
                            duration: MotionTokens.micro,
                            opacity: mainIndex < 0 ? 0.0 : 1.0,
                            child: _GlossyPill(colors: colors),
                          ),
                        ),
                        Row(
                          children: [
                            for (final spec in _mainTabs)
                              SizedBox(
                                width: itemWidth,
                                child: _NavItem(
                                  spec: spec,
                                  label: _labelFor(spec.tab, l10n),
                                  selected: spec.tab == selected,
                                  onTap: () => selectTab(spec.tab),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
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
            onTap: () => selectTab(AppTab.search),
          ),
        ],
      ),
    );

    // Collapse + fade + slide-down as the bar hides. `heightFactor` shrinks the
    // vertical space it occupies (so the mini player above slides to the
    // bottom), `Opacity` makes it vanish, and the translate adds a gentle drop.
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

/// The glossy selected-tab capsule — a top-lit translucent fill with a soft
/// white rim, so the active tab reads as a small piece of lit Liquid Glass.
class _GlossyPill extends StatelessWidget {
  const _GlossyPill({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: RadiusTokens.brPill,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.onSurface.withOpacity(0.16),
            colors.onSurface.withOpacity(0.07),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
    );
  }
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
    final color = widget.selected ? colors.onSurface : colors.onSurfaceFaint;

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
          scale: _pressed ? 0.88 : 1.0,
          duration: MotionTokens.press,
          curve: MotionTokens.standard,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: MotionTokens.micro,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    widget.selected ? widget.spec.activeIcon : widget.spec.icon,
                    key: ValueKey(widget.selected),
                    size: 22,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: MotionTokens.micro,
                  style: AppTextTheme.navLabel.copyWith(
                    color: color,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The standalone circular Search bubble. When selected it fills with the same
/// glossy Liquid-Glass capsule used by the active tab.
class _SearchBubble extends StatefulWidget {
  const _SearchBubble({
    required this.label,
    required this.selected,
    required this.intensity,
    required this.size,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final GlassIntensity intensity;
  final double size;
  final VoidCallback onTap;

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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.onSurface.withOpacity(0.16),
                              colors.onSurface.withOpacity(0.07),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 1,
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
