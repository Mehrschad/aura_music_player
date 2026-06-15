// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../providers/scrobbler_provider.dart';
import '../../providers/settings_providers.dart';

/// Full auth flow: enter credentials → get auth URL → complete → connected.
class LastFmConnectPage extends ConsumerStatefulWidget {
  const LastFmConnectPage({super.key});

  @override
  ConsumerState<LastFmConnectPage> createState() => _LastFmConnectPageState();
}

class _LastFmConnectPageState extends ConsumerState<LastFmConnectPage> {
  final _apiKeyCtrl = TextEditingController();
  final _apiSecretCtrl = TextEditingController();

  String? _token;
  String? _authUrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _apiKeyCtrl.text = s.lastFmApiKey;
    _apiSecretCtrl.text = s.lastFmApiSecret;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _apiSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _getToken() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final key = _apiKeyCtrl.text.trim();
      final secret = _apiSecretCtrl.text.trim();
      final client = ref.read(lastFmClientProvider);
      final token = await client.getToken(key, secret);
      setState(() {
        _token = token;
        // Auth URL includes both api_key and token per Last.fm docs.
        _authUrl =
            'https://www.last.fm/api/auth/?api_key=${Uri.encodeComponent(key)}&token=${Uri.encodeComponent(token)}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _completeAuth() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final key = _apiKeyCtrl.text.trim();
      final secret = _apiSecretCtrl.text.trim();
      final client = ref.read(lastFmClientProvider);
      final result = await client.getSession(token, key, secret);
      final n = ref.read(settingsProvider.notifier);
      n.setLastFmApiKey(key);
      n.setLastFmApiSecret(secret);
      n.setLastFmSessionKey(result.sessionKey);
      n.setLastFmUsername(result.username);
      n.setLastFm(true);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _disconnect() {
    final n = ref.read(settingsProvider.notifier);
    n.setLastFmSessionKey('');
    n.setLastFmUsername('');
    n.setLastFm(false);
    setState(() {
      _token = null;
      _authUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final isConnected = s.lastFmSessionKey.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(
          l10n.lastFmConnect,
          style: AppTextTheme.title.copyWith(color: colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SpacingTokens.xl),
        children: [
          if (isConnected) ...[
            // Connected state: show username and disconnect.
            _StatusCard(
              label: l10n.lastFmConnectedAs(s.lastFmUsername),
              colors: colors,
            ),
            const SizedBox(height: SpacingTokens.lg),
            _ActionButton(
              label: l10n.lastFmDisconnect,
              onPressed: _disconnect,
              colors: colors,
              outlined: true,
            ),
          ] else ...[
            // Step 1: Enter API key and secret.
            TextField(
              controller: _apiKeyCtrl,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: l10n.lastFmApiKey,
                filled: true,
                fillColor: colors.surfaceElevated,
                border: const OutlineInputBorder(
                  borderRadius: RadiusTokens.brSm,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.md),
            TextField(
              controller: _apiSecretCtrl,
              obscureText: true,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: l10n.lastFmApiSecret,
                filled: true,
                fillColor: colors.surfaceElevated,
                border: const OutlineInputBorder(
                  borderRadius: RadiusTokens.brSm,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.lg),

            if (_authUrl == null) ...[
              // Step 2: Fetch the auth token and build auth URL.
              _ActionButton(
                label: l10n.lastFmGetAuthUrl,
                onPressed: _loading ? null : _getToken,
                colors: colors,
                loading: _loading,
              ),
            ] else ...[
              // Step 3: Show auth URL for user to open in browser.
              Text(
                l10n.lastFmAuthUrlHint,
                style: AppTextTheme.caption
                    .copyWith(color: colors.onSurfaceMuted),
              ),
              const SizedBox(height: SpacingTokens.sm),
              _UrlBox(url: _authUrl!, colors: colors),
              const SizedBox(height: SpacingTokens.lg),
              // Step 4: Exchange authorized token for session key.
              _ActionButton(
                label: l10n.lastFmComplete,
                onPressed: _loading ? null : _completeAuth,
                colors: colors,
                loading: _loading,
              ),
            ],
          ],

          if (_error != null) ...[
            const SizedBox(height: SpacingTokens.md),
            Text(
              _error!,
              style: AppTextTheme.caption.copyWith(
                  color: Theme.of(context).colorScheme.error),
            ),
          ],

          // Show how many scrobbles are waiting to be sent.
          const SizedBox(height: SpacingTokens.xl),
          Consumer(builder: (context, ref, _) {
            final queue = ref.watch(scrobbleQueueProvider);
            if (queue.isEmpty) return const SizedBox.shrink();
            final l = AppLocalizations.of(context);
            return Text(
              l.lastFmPendingScrobbles(queue.length),
              style: AppTextTheme.caption
                  .copyWith(color: colors.onSurfaceMuted),
            );
          }),
        ],
      ),
    );
  }
}

// ── Internal widgets ─────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.label, required this.colors});
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: RadiusTokens.brMd,
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: colors.accent),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Text(
              label,
              style: AppTextTheme.body.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlBox extends StatelessWidget {
  const _UrlBox({required this.url, required this.colors});
  final String url;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: RadiusTokens.brSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            url,
            style: AppTextTheme.caption.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: url)),
            icon: Icon(
              Icons.copy,
              size: SpacingTokens.lg,
              color: colors.accent,
            ),
            label: Text(
              AppLocalizations.of(context).copyUrl,
              style: AppTextTheme.caption.copyWith(color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.colors,
    this.loading = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppColors colors;
  final bool loading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: AppTextTheme.body.copyWith(color: colors.onSurface),
        ),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      child: loading
          ? const SizedBox.square(
              dimension: SpacingTokens.lg,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
