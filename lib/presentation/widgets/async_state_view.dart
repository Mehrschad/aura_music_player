import 'package:flutter/material.dart';

import '../../core/constants/spacing_tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/color_scheme.dart';
import '../../core/theme/typography.dart';

/// Renders an [AsyncValue] with Aura's consistent loading / error / empty /
/// data treatment, so every section handles these states identically.
///
/// Loading is intentionally quiet — a small, low-contrast spinner rather than a
/// jarring full-screen one. Empty and error states are centred and calm with an
/// optional retry.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.data,
    required this.isEmpty,
    required this.emptyMessage,
    this.emptyIcon = Icons.library_music_outlined,
    this.onRetry,
  });

  final AsyncValueLike<T> value;
  final Widget Function(T data) data;
  final bool Function(T data) isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.map(
      loading: () => const _Loading(),
      error: (err) => _ErrorState(onRetry: onRetry),
      data: (d) => isEmpty(d)
          ? _Centered(icon: emptyIcon, message: emptyMessage)
          : data(d),
    );
  }
}

/// A tiny adapter so this widget doesn't hard-depend on Riverpod's AsyncValue
/// type signature, keeping it trivially unit-testable. Callers wrap with
/// [AsyncValueLike.from].
class AsyncValueLike<T> {
  const AsyncValueLike._(this._state, this._data, this._error);

  factory AsyncValueLike.data(T data) =>
      AsyncValueLike._(_AsyncState.data, data, null);
  factory AsyncValueLike.loading() =>
      AsyncValueLike._(_AsyncState.loading, null, null);
  factory AsyncValueLike.error(Object error) =>
      AsyncValueLike._(_AsyncState.error, null, error);

  final _AsyncState _state;
  final T? _data;
  final Object? _error;

  R map<R>({
    required R Function() loading,
    required R Function(Object error) error,
    required R Function(T data) data,
  }) {
    switch (_state) {
      case _AsyncState.loading:
        return loading();
      case _AsyncState.error:
        return error(_error!);
      case _AsyncState.data:
        return data(_data as T);
    }
  }
}

enum _AsyncState { loading, error, data }

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.onSurfaceFaint,
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colors.onSurfaceFaint),
          const SizedBox(height: SpacingTokens.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: colors.onSurfaceFaint),
          const SizedBox(height: SpacingTokens.md),
          Text(
            l10n.errorGeneric,
            style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: SpacingTokens.md),
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ],
      ),
    );
  }
}
