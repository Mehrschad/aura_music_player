import '../../domain/widgets/home_widget_state.dart';

/// Pushes [HomeWidgetState] to the native home-screen widgets.
///
/// [NoopHomeWidgetSync] is active (no plugin). On device, implement with
/// `home_widget`:
///
/// ```dart
/// class HomeWidgetPlugin implements HomeWidgetSync {
///   @override
///   Future<void> push(HomeWidgetState s) async {
///     for (final e in s.toWidgetData().entries) {
///       await HomeWidget.saveWidgetData<String>(e.key, e.value);
///     }
///     await HomeWidget.updateWidget(
///       name: 'AuraWidgetProvider',          // Android provider class
///       iOSName: 'AuraWidget',               // iOS widget kind
///     );
///   }
/// }
/// ```
///
/// The three sizes (2×1 mini, 4×1 standard, 4×2 large) are native layouts that
/// read these keys. Background refresh is scheduled with `workmanager` so the
/// widgets stay current while the app is backgrounded; widget control taps come
/// back via `HomeWidget.widgetClicked` and route to the audio handler.
abstract interface class HomeWidgetSync {
  Future<void> push(HomeWidgetState state);
}

class NoopHomeWidgetSync implements HomeWidgetSync {
  const NoopHomeWidgetSync();

  @override
  Future<void> push(HomeWidgetState state) async {}
}
