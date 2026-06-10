import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/albums/albums_page.dart';
import '../pages/artists/artists_page.dart';
import '../pages/library/library_page.dart';
import '../pages/playlists/playlists_page.dart';
import '../pages/search/search_page.dart';
import '../providers/home_widget_providers.dart';
import '../widgets/player/mini_player.dart';
import 'glass_nav_bar.dart';
import 'nav_provider.dart';

/// The root scaffold: the five primary sections stacked behind a floating
/// Liquid Glass nav bar.
///
/// Each tab has its own nested [Navigator] so that detail pages (album, artist,
/// playlist) can be pushed WITHOUT hiding the mini player and nav bar.
/// [NowPlayingPage] is the exception — it uses `rootNavigator: true` to cover
/// the whole screen.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<Widget> _roots = [
    LibraryPage(),
    ArtistsPage(),
    AlbumsPage(),
    PlaylistsPage(),
    SearchPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(selectedTabProvider);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: tab.index,
        children: [for (final page in _roots) _TabNavigator(root: page)],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _HomeWidgetBridge(),
          MiniPlayer(),
          GlassNavBar(),
        ],
      ),
    );
  }
}

/// A nested [Navigator] for a single bottom-nav tab.
/// Pushes within this tab stay INSIDE, so the host Scaffold's bottom bar
/// (mini player + nav bar) remains visible.
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.root});
  final Widget root;

  @override
  Widget build(BuildContext context) {
    return Navigator(
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
