import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/playback.dart';
import '../../../domain/widgets/home_widget_state.dart';
import '../../providers/home_widget_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';

Future<void> openWidgetPreview(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const WidgetPreviewPage()),
  );
}

class WidgetPreviewPage extends ConsumerWidget {
  const WidgetPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(homeWidgetStateProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(l10n.homeWidgets,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        children: [
          Text(l10n.widgetPreviewNote,
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint)),
          const SizedBox(height: SpacingTokens.lg),
          _Labelled(l10n.widgetMini, _MiniWidget(state: state)),
          const SizedBox(height: SpacingTokens.lg),
          _Labelled(l10n.widgetStandard, _StandardWidget(state: state)),
          const SizedBox(height: SpacingTokens.lg),
          _Labelled(l10n.widgetLarge, _LargeWidget(state: state)),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted)),
        const SizedBox(height: SpacingTokens.sm),
        child,
      ],
    );
  }
}

/// Shared frosted container the widgets sit in.
class _WidgetFrame extends StatelessWidget {
  const _WidgetFrame({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: height,
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: RadiusTokens.brLg,
      ),
      child: child,
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.state, required this.size});
  final HomeWidgetState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: RadiusTokens.brSm,
      child: AuraArtwork(
        seed: state.artworkSeed.isEmpty ? 'widget' : state.artworkSeed,
        size: size,
        hasArtwork: state.hasArtwork,
      ),
    );
  }
}

class _TitleArtist extends StatelessWidget {
  const _TitleArtist({required this.state, this.showArtist = true});
  final HomeWidgetState state;
  final bool showArtist;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          state.hasMedia ? state.title : l10n.widgetNoMedia,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.title.copyWith(color: colors.onSurface),
        ),
        if (showArtist && state.hasMedia)
          Text(state.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted)),
      ],
    );
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.playing});
  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return IconButton(
      onPressed: () => ref.read(audioControllerProvider).togglePlayPause(),
      icon: Icon(playing ? Icons.pause : Icons.play_arrow,
          color: colors.onSurface),
    );
  }
}

class _MiniWidget extends StatelessWidget {
  const _MiniWidget({required this.state});
  final HomeWidgetState state;

  @override
  Widget build(BuildContext context) {
    return _WidgetFrame(
      height: 80,
      child: Row(
        children: [
          _Art(state: state, size: 56),
          const SizedBox(width: SpacingTokens.md),
          Expanded(child: _TitleArtist(state: state, showArtist: false)),
          _PlayButton(playing: state.playing),
        ],
      ),
    );
  }
}

class _StandardWidget extends ConsumerWidget {
  const _StandardWidget({required this.state});
  final HomeWidgetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final controller = ref.read(audioControllerProvider);
    return _WidgetFrame(
      height: 96,
      child: Row(
        children: [
          _Art(state: state, size: 64),
          const SizedBox(width: SpacingTokens.md),
          Expanded(child: _TitleArtist(state: state)),
          IconButton(
            onPressed: controller.skipToPrevious,
            icon: Icon(Icons.skip_previous, color: colors.onSurfaceMuted),
          ),
          _PlayButton(playing: state.playing),
          IconButton(
            onPressed: controller.skipToNext,
            icon: Icon(Icons.skip_next, color: colors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _LargeWidget extends ConsumerWidget {
  const _LargeWidget({required this.state});
  final HomeWidgetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final controller = ref.read(audioControllerProvider);
    final accent = SeedPalette.accent(
        state.artworkSeed.isEmpty ? 'widget' : state.artworkSeed);
    return _WidgetFrame(
      height: 180,
      child: Column(
        children: [
          Row(
            children: [
              _Art(state: state, size: 72),
              const SizedBox(width: SpacingTokens.md),
              Expanded(child: _TitleArtist(state: state)),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          ClipRRect(
            borderRadius: RadiusTokens.brPill,
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 4,
              backgroundColor: colors.divider,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () =>
                    controller.setShuffle(!state.shuffle),
                icon: Icon(Icons.shuffle,
                    color: state.shuffle ? accent : colors.onSurfaceMuted),
              ),
              IconButton(
                onPressed: controller.skipToPrevious,
                icon: Icon(Icons.skip_previous, color: colors.onSurface),
              ),
              _PlayButton(playing: state.playing),
              IconButton(
                onPressed: controller.skipToNext,
                icon: Icon(Icons.skip_next, color: colors.onSurface),
              ),
              IconButton(
                onPressed: () => controller.setRepeatMode(
                    _nextRepeat(state.repeat)),
                icon: Icon(
                  state.repeat == RepeatMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                  color: state.repeat == RepeatMode.off
                      ? colors.onSurfaceMuted
                      : accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

RepeatMode _nextRepeat(RepeatMode m) => switch (m) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
