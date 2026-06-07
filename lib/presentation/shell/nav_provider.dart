import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The five primary sections, in tab order.
enum AppTab { library, artists, albums, playlists, search }

/// Holds the currently selected primary tab.
///
/// Kept as a plain [StateProvider] for now; once routing grows (deep links,
/// nested navigators) this becomes a small Notifier. Step 1 only needs the
/// index.
final selectedTabProvider = StateProvider<AppTab>((ref) => AppTab.library);

/// Static metadata for each tab. Labels are resolved from l10n at the call
/// site (see `glass_nav_bar.dart`), so only the icons live here.
class TabSpec {
  const TabSpec(this.tab, this.icon, this.activeIcon);
  final AppTab tab;
  final IconData icon;
  final IconData activeIcon;
}
