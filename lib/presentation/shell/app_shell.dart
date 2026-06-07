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
/// An [IndexedStack] keeps each section's scroll position and state alive
/// when switching tabs (you don't lose your place in the library because you
/// glanced at Search). The body extends behind the nav bar so the glass has
/// real content to blur — `extendBody: true`.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<Widget> _pages = [
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
      body: IndexedStack(index: tab.index, children: _pages),
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
