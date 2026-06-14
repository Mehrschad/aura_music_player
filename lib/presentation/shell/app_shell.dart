import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/albums/albums_page.dart';
import '../pages/artists/artists_page.dart';
import '../pages/library/library_page.dart';
import '../pages/playlists/playlists_page.dart';
import '../pages/search/search_page.dart';
import '../providers/engine_bridge_provider.dart';
import '../providers/home_widget_providers.dart';
import '../providers/selection_providers.dart';
import '../widgets/library/offline_prefetcher.dart';
import '../widgets/player/listening_recorder.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/player/playback_persistor.dart';
import 'glass_nav_bar.dart';
import 'nav_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  final List<GlobalKey<NavigatorState>> _navKeys = List.generate(
    AppTab.values.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  late final AnimationController _tabCtrl;
  late final Animation<double> _tabProgress;

  int _prevTabIndex = 0;
  int _slideDir = 1;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _tabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..value = 1.0; // start "done" — no enter animation on first load
    _tabProgress = CurvedAnimation(parent: _tabCtrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    // 0. An active multi-selection swallows back first — it just clears.
    for (final scope in const [
      SelectionScopes.library,
      SelectionScopes.search,
    ]) {
      if (ref.read(selectionProvider(scope)).active) {
        ref.read(selectionProvider(scope).notifier).clear();
        return false;
      }
    }

    final tabIndex = ref.read(selectedTabProvider).index;
    final key = _navKeys[tabIndex];

    // 1. If the current tab's nested navigator has pages, pop one.
    if (key.currentState?.canPop() ?? false) {
      key.currentState!.pop();
      return false;
    }

    // 2. If not on Library tab, go to Library tab.
    if (tabIndex != AppTab.library.index) {
      ref.read(selectedTabProvider.notifier).state = AppTab.library;
      return false;
    }

    // 3. Double-press to exit from Library root.
    final now = DateTime.now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return false;
    }
    _lastBackPress = now;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(selectedTabProvider);
    final tabIndex = tab.index;

    // Listen for tab changes to drive the directional slide animation.
    ref.listen(selectedTabProvider, (prev, next) {
      if (prev != null && prev != next) {
        _prevTabIndex = prev.index;
        _slideDir = next.index > prev.index ? 1 : -1;
        _tabCtrl.forward(from: 0);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _handleBack(),
      child: Scaffold(
        extendBody: true,
        body: AnimatedBuilder(
          animation: _tabCtrl,
          builder: (context, _) {
            final t = _tabProgress.value;
            final isAnim = _tabCtrl.isAnimating;
            final W = MediaQuery.sizeOf(context).width * 0.25;
            return Stack(
              children: [
                for (var i = 0; i < AppTab.values.length; i++)
                  Positioned.fill(
                    child: _buildTabSlot(i, tabIndex, t, isAnim, W),
                  ),
              ],
            );
          },
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _HomeWidgetBridge(),
            OfflinePrefetcher(),
            PlaybackPersistor(),
            ListeningRecorder(),
            MiniPlayer(),
            GlassNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSlot(int i, int tabIndex, double t, bool isAnim, double W) {
    final nav = _TabNavigator(
      navigatorKey: _navKeys[i],
      root: _rootForTab(AppTab.values[i]),
    );

    final isActive = i == tabIndex;
    final isOut = i == _prevTabIndex && isAnim && i != tabIndex;

    double dx, opacity;
    if (isActive) {
      // Incoming: slides in from the skip direction and fades in.
      dx = _slideDir * (1.0 - t) * W;
      opacity = t;
    } else if (isOut) {
      // Outgoing: slides away and fades out.
      dx = -_slideDir * t * W;
      opacity = 1.0 - t;
    } else {
      // Inactive — invisible, zero overhead.
      dx = 0;
      opacity = 0;
    }

    return IgnorePointer(
      ignoring: !isActive,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: nav,
        ),
      ),
    );
  }

  Widget _rootForTab(AppTab tab) => switch (tab) {
        AppTab.library => const LibraryPage(),
        AppTab.artists => const ArtistsPage(),
        AppTab.albums => const AlbumsPage(),
        AppTab.playlists => const PlaylistsPage(),
        AppTab.search => const SearchPage(),
      };
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.root});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root),
    );
  }
}

/// Invisible bridge: pushes the live [HomeWidgetState] to the native home-screen
/// widgets whenever it changes (no-op until the `home_widget` plugin is wired).
class _HomeWidgetBridge extends ConsumerWidget {
  const _HomeWidgetBridge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wire settings (pitch, skip-silence, ReplayGain, crossfade) to the engine.
    ref.watch(engineBridgeProvider);
    ref.listen(homeWidgetStateProvider, (_, next) {
      ref.read(homeWidgetSyncProvider).push(next);
    });
    return const SizedBox.shrink();
  }
}
