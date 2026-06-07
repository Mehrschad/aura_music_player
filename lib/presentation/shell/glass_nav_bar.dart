import 'package:flutter/material.dart';
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

/// The floating Liquid Glass bottom navigation bar.
///
/// Floats 16px above the bottom safe area with horizontal margin. Five tabs,
/// label + icon, with a subtle press-scale and a smoothly animated active
/// state. The bar itself is the only chrome — the mini player sits *above* it
/// (wired up in a later build step).
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
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: SpacingTokens.lg,
        right: SpacingTokens.lg,
        bottom: SpacingTokens.lg + bottomInset,
      ),
      child: GlassSurface(
        borderRadius: RadiusTokens.brXl,
        intensity: ref.watch(
            settingsProvider.select((s) => s.glassIntensity)),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final spec in _tabs)
                _NavItem(
                  spec: spec,
                  label: _labelFor(spec.tab, l10n),
                  selected: spec.tab == selected,
                  onTap: () =>
                      ref.read(selectedTabProvider.notifier).state = spec.tab,
                ),
            ],
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
    final activeColor = colors.onSurface;
    final inactiveColor = colors.onSurfaceFaint;
    final color = widget.selected ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: MotionTokens.press,
          curve: MotionTokens.standard,
          child: ConstrainedBox(
            // Honour the 44x44 minimum touch target.
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: MotionTokens.micro,
                  child: Icon(
                    widget.selected ? widget.spec.activeIcon : widget.spec.icon,
                    key: ValueKey(widget.selected),
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(widget.label, style: AppTextTheme.navLabel.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
