import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/albums/albums_page.dart';
import '../pages/artists/artists_page.dart';
import '../pages/library/library_page.dart';
import '../pages/onboarding/onboarding_page.dart';
import '../pages/playlists/playlists_page.dart';
import '../pages/search/search_page.dart';
import '../providers/cover_palette_provider.dart';
import '../providers/engine_bridge_provider.dart';
import '../providers/home_widget_providers.dart';
import '../providers/playback_providers.dart';
import '../providers/scrobbler_provider.dart';
import '../providers/selection_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/library/offline_prefetcher.dart';
import '../widgets/player/listening_recorder.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/player/playback_persistor.dart';
import 'glass_nav_bar.dart';
import 'nav_provider.dart';

/// Sustained vertical travel (px) required before the floating nav bar toggles
/// its minimized state — high enough to ignore jitter, low enough to feel
/// responsive to a deliberate scroll.
const double _kScrollToggleThreshold = 40;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(settingsProvider).onboardingSeen) {
        openOnboarding(context);
      }
    });
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

    // Current track palette for ambient colour behind the glass layer.
    final song = ref.watch(currentSongProvider);
    final ambientWash = song == null
        ? null
        : ref
            .watch(coverPaletteProvider((
              seed: song.artworkSeed,
              hasArtwork: song.hasArtwork,
              artworkId: int.tryParse(song.id),
            )))
            .valueOrNull
            ?.wash;

    // Listen for tab changes to drive the directional slide animation, and
    // expand the floating nav bar (a fresh tab always starts at the top).
    ref.listen(selectedTabProvider, (prev, next) {
      if (prev != null && prev != next) {
        _prevTabIndex = prev.index;
        _slideDir = next.index > prev.index ? 1 : -1;
        _tabCtrl.forward(from: 0);
        if (ref.read(navMinimizedProvider)) {
          ref.read(navMinimizedProvider.notifier).state = false;
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _handleBack(),
      child: Scaffold(
        extendBody: true,
        // Watch vertical scrolling anywhere in the page content to minimize /
        // expand the floating nav bar the way iOS 26 tab bars do.
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: AnimatedBuilder(
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
                // Ambient colour glow: the current track's wash bleeds
                // through the bottom glass (mini player + nav bar) so the
                // frosting becomes obvious even over a near-black background.
                // This is the "Apple Music whole-page tint" effect.
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 260,
                  child: IgnorePointer(
                    child: _AmbientGlow(wash: ambientWash),
                  ),
                ),
              ],
            );
          },
          ),
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

  /// Accumulated same-direction scroll distance, used to gate the minimize /
  /// expand toggle behind a small threshold so the bar doesn't flicker on tiny
  /// finger jitters. Reset whenever the scroll direction reverses.
  double _scrollAccum = 0;

  /// Minimizes the floating nav bar while scrolling down through vertical
  /// content and expands it again on scroll up — the iOS 26 tab-bar behaviour.
  ///
  /// Rather than flipping on the slightest direction change (which felt twitchy),
  /// the toggle requires a sustained [_kScrollToggleThreshold] px of travel in
  /// one direction, and the bar always re-expands the moment the content reaches
  /// the very top. Horizontal scrollers (album carousels) are ignored.
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;

    // At (or above) the top, always reveal the bar — no threshold needed.
    if (n.metrics.pixels <= 0.5) {
      _scrollAccum = 0;
      if (ref.read(navMinimizedProvider)) {
        ref.read(navMinimizedProvider.notifier).state = false;
      }
      return false;
    }

    if (n is! ScrollUpdateNotification) return false;
    final delta = n.scrollDelta ?? 0;
    if (delta == 0) return false;

    final goingDown = delta > 0;
    // Reset the run when the user reverses direction, so a flick the other way
    // responds promptly instead of fighting the previous run's accumulation.
    if ((goingDown && _scrollAccum < 0) || (!goingDown && _scrollAccum > 0)) {
      _scrollAccum = 0;
    }
    _scrollAccum += delta;

    final minimized = ref.read(navMinimizedProvider);
    if (_scrollAccum > _kScrollToggleThreshold && !minimized) {
      ref.read(navMinimizedProvider.notifier).state = true;
      _scrollAccum = 0;
    } else if (_scrollAccum < -_kScrollToggleThreshold && minimized) {
      ref.read(navMinimizedProvider.notifier).state = false;
      _scrollAccum = 0;
    }
    return false;
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

/// The colour glow behind the glass nav bar + mini player.
///
/// When a track is playing, the artwork's `wash` colour bleeds upward as a
/// translucent gradient so the [GlassSurface] backdrop-filter has colourful
/// content to blur — making the frosted-glass look clearly visible even over
/// a uniform near-black or white page background.
///
/// Animates smoothly between colours as the track changes.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({this.wash});
  final Color? wash;

  @override
  Widget build(BuildContext context) {
    final target = wash ?? Colors.transparent;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, color, _) {
        final c = color ?? Colors.transparent;
        if (c == Colors.transparent) return const SizedBox.expand();
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.withOpacity(0),
                c.withOpacity(0.22),
                c.withOpacity(0.44),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        );
      },
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
    // Wire Last.fm scrobbling (no-op when disabled or unauthenticated).
    ref.watch(scrobblerProvider);
    ref.listen(homeWidgetStateProvider, (_, next) {
      ref.read(homeWidgetSyncProvider).push(next);
    });
    return const SizedBox.shrink();
  }
}
