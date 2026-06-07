import 'package:aura_music_player/core/l10n/app_localizations.dart';
import 'package:aura_music_player/core/theme/app_theme.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/presentation/pages/tag_editor/tag_editor_page.dart';
import 'package:aura_music_player/presentation/providers/library_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song() => Song(
      id: 's1',
      title: 'Old Title',
      artist: 'A',
      album: 'Al',
      albumId: 'al1',
      artistId: 'ar1',
      duration: const Duration(seconds: 100),
      filePath: '/m/s1.flac',
      dateAdded: DateTime(2024),
    );

void main() {
  testWidgets('editing a field and saving writes a tag override',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(flavor: DarkFlavor.amoled),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TagEditorPage(songs: [_song()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First text field is Title.
    await tester.enterText(find.byType(TextField).first, 'New Title');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final override = container.read(tagOverridesProvider)['s1'];
    expect(override, isNotNull);
    expect(override!.title, 'New Title');
  });
}
