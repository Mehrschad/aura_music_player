import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';

/// Prompts for a playlist name. Returns the trimmed name, or null if cancelled.
/// Used for both creating ([initial] null) and renaming.
Future<String?> promptPlaylistName(BuildContext context, {String? initial}) {
  final controller = TextEditingController(text: initial ?? '');
  final colors = context.colors;
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: RadiusTokens.brLg),
      title: Text(
        initial == null ? l10n.playlistNew : l10n.rename,
        style: AppTextTheme.title.copyWith(color: colors.onSurface),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: AppTextTheme.body.copyWith(color: colors.onSurface),
        decoration: InputDecoration(
          hintText: l10n.playlistNameHint,
          hintStyle: AppTextTheme.body.copyWith(color: colors.onSurfaceFaint),
        ),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(initial == null ? l10n.create : l10n.save),
        ),
      ],
    ),
  ).then((value) => (value == null || value.isEmpty) ? null : value);
}

/// Confirms deleting a playlist. Returns true if confirmed.
Future<bool> confirmDeletePlaylist(BuildContext context, String name) async {
  final colors = context.colors;
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: RadiusTokens.brLg),
      title: Text(
        '${l10n.delete} "$name"?',
        style: AppTextTheme.title.copyWith(color: colors.onSurface),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
