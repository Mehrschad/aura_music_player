import 'package:aura_music_player/core/l10n/app_localizations.dart';
import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:aura_music_player/presentation/pages/playlists/smart_playlist_editor_page.dart';
import 'package:aura_music_player/presentation/providers/smart_playlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creating a smart playlist persists it', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(flavor: DarkFlavor.amoled),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SmartPlaylistEditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'My Smart List');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final all = await container.read(smartPlaylistRepositoryProvider).all();
    expect(all.any((p) => p.name == 'My Smart List'), isTrue);
  });
}
