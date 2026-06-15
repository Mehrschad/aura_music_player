import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/motion_tokens.dart';
import '../../core/constants/radius_tokens.dart';
import '../../core/constants/spacing_tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/color_scheme.dart';
import '../../core/theme/typography.dart';
import '../widgets/glass/glass_surface.dart';
import '../providers/settings_providers.dart';
import 'nav_provider.dart';

class GlassNavBar extends ConsumerWidget {
  const GlassNavBar({super.key});

  static const List<TabSpec> _tabs = [
    TabSpec(AppTab.library, Icons.library_music_outlined, Icons.library_music),
    TabSpec(AppTab.artists, Icons.person_outline, Icons.person),
    TabSpec(AppTab.albums, Icons.album_outlined, Icons.album),
    TabSpec(AppTab.playlists, Icons.queue_music_outlined, Icons.queue_music),
    TabSpec(AppTab.search, Icons.search_outlined, Icons.search),
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
    final selectedIndex = AppTab.values.indexOf(selected);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final intensity = ref.watch(settingsProvider.select((s) => s.glassIntensity));
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: SpacingTokens.lg,
        right: SpacingTokens.lg,
        bottom: SpacingTokens.lg + bottomInset,
      ),
      child: GlassSurface(
        // Fully-rounded stadium shell — matched to the mini player above it so
        // the two floating bars share one clean, pill-shaped language.
        borderRadius: RadiusTokens.brPill,
        intensity: intensity,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _tabs.length;
              final pillWidth = itemWidth - 16;
              final pillLeft =
                  selectedIndex * itemWidth + (itemWidth - pillWidth) / 2;

              return Stack(
                children: [
                  // Animated glass pill / capsule indicator.
                  //
                  // Positioned by `start` (not `left`) so it mirrors correctly
                  // in RTL (fa/ar): the tab Row lays out from the start edge, so
                  // measuring the pill offset from the same start edge keeps it
                  // under the selected tab in both directions.
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: pillLeft, end: pillLeft),
                    duration: MotionTokens.screen,
                    curve: MotionTokens.spring,
                    builder: (context, start, _) => PositionedDirectional(
                      start: start,
                      top: (64 - 44) / 2,
                      width: pillWidth,
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.onSurface.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: colors.onSurface.withOpacity(0.06),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tab items row — sits above the pill
                  Row(
                    children: [
                      for (final spec in _tabs)
                        SizedBox(
                          width: itemWidth,
                          child: _NavItem(
                            spec: spec,
                            label: _labelFor(spec.tab, l10n),
                            selected: spec.tab == selected,
                            onTap: () =>
                                ref.read(selectedTabProvider.notifier).state =
                                    spec.tab,
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
