import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/albums/albums_page.dart';
import '../pages/artists/artists_page.dart';
import '../pages/library/library_page.dart';
import '../pages/playlists/playlists_page.dart';
import '../pages/search/search_page.dart';
import '../providers/home_widget_providers.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/player/playback_persistor.dart';
import 'glass_nav_bar.dart';
import 'nav_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // One key per tab so we can pop their inner navigators.
  final List<GlobalKey<NavigatorState>> _navKeys = List.generate(
    AppTab.values.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  DateTime? _lastBackPress;

  Future<bool> _handleBack() async {
    final tabIndex = ref.read(selectedTabProvider).index;
    final key = _navKeys[tabIndex];

    // 1. If the current tab's nested navigator has pages, pop one.
    if (key.currentState?.canPop() ?? false) {
      key.currentState!.pop();
      return false; // don't exit
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
    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _handleBack(),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: tab.index,
          children: [
            for (var i = 0; i < AppTab.values.length; i++)
              _TabNavigator(
                navigatorKey: _navKeys[i],
                root: _rootForTab(AppTab.values[i]),
              ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _HomeWidgetBridge(),
            PlaybackPersistor(),
            MiniPlayer(),
            GlassNavBar(),
          ],
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
    ref.listen(homeWidgetStateProvider, (_, next) {
      ref.read(homeWidgetSyncProvider).push(next);
    });
    return const SizedBox.shrink();
  }
}
