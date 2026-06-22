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
/// it, and the whole bar minimizes (labels collapse, height shrinks) while the
/// user scrolls down through content.
class GlassNavBar extends ConsumerWidget {
  const GlassNavBar({super.key});

  /// Primary tabs in the main pill. Search is intentionally excluded — it gets
  /// its own bubble, mirroring the iOS 26 Music / App Store layout.
  static const List<TabSpec> _mainTabs = [
    TabSpec(AppTab.library, Icons.library_music_outlined, Icons.library_music),
    TabSpec(AppTab.artists, Icons.person_outline, Icons.person),
    TabSpec(AppTab.albums, Icons.album_outlined, Icons.album),
    TabSpec(AppTab.playlists, Icons.queue_music_outlined, Icons.queue_music),
  ];

  String _labelFor(AppTab tab, AppLocalizations l10n) => switch (tab) {
        AppTab.library => l10n.tabLibrary,
        AppTab.artists => l10n.tabArtists,
        AppTab.albums => l10n.tabAlbums,
        AppTab.playlists => l10n.tabPlaylists,
        AppTab.search => l10n.tabSearch,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final intensity = ref.watch(settingsProvider.select((s) => s.glassIntensity));
    final minimized = ref.watch(navMinimizedProvider);
    final colors = context.colors;

    final barHeight = minimized ? 52.0 : 64.0;
    final mainIndex = _mainTabs.indexWhere((t) => t.tab == selected);

    void selectTab(AppTab tab) {
      HapticFeedback.selectionClick();
      ref.read(selectedTabProvider.notifier).state = tab;
    }

    return Padding(
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
              child: AnimatedContainer(
                duration: MotionTokens.micro,
                curve: MotionTokens.standard,
                height: barHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / _mainTabs.length;
                    final pillWidth = itemWidth - 14;
                    final pillHeight = barHeight - 18;
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
                                  minimized: minimized,
                                  height: barHeight,
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
    required this.minimized,
    required this.height,
    required this.onTap,
  });

  final TabSpec spec;
  final String label;
  final bool selected;
  final bool minimized;
  final double height;
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
            height: widget.height,
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
                // Label collapses away when the bar is minimized.
                AnimatedSize(
                  duration: MotionTokens.micro,
                  curve: MotionTokens.standard,
                  child: widget.minimized
                      ? const SizedBox(width: 0, height: 0)
                      : Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: AnimatedDefaultTextStyle(
                            duration: MotionTokens.micro,
                            style: AppTextTheme.navLabel.copyWith(
                              color: color,
                              fontWeight: widget.selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            child: Text(widget.label),
                          ),
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
