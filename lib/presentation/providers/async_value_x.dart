import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/async_state_view.dart';

/// Adapts Riverpod's [AsyncValue] to the UI-layer [AsyncValueLike] consumed by
/// [AsyncStateView]. Keeps the view widget free of a Riverpod dependency.
extension AsyncValueBridge<T> on AsyncValue<T> {
  AsyncValueLike<T> get like => when(
        data: AsyncValueLike<T>.data,
        loading: AsyncValueLike<T>.loading,
        error: (e, _) => AsyncValueLike<T>.error(e),
      );
}
