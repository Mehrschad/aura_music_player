import '../../core/theme/glass_theme.dart';

enum ThemePref { system, light, dark, amoled }

enum ReplayGainMode { off, track, album }

enum InterruptionBehavior { pause, duck, ignore }

enum DisplayDensity { comfortable, standard, compact }

/// Selectable UI language; [system] follows the device locale.
enum LocalePref { system, en, fa, ar }

/// All user-facing preferences. Immutable; the [SettingsNotifier] swaps in new
/// instances and the [SettingsRepository] persists them.
class AppSettings {
  const AppSettings({
    this.themePref = ThemePref.amoled,
    this.glassIntensity = GlassIntensity.strong,
    this.dynamicColor = true,
    this.textScale = 1.0,
    this.density = DisplayDensity.standard,
    this.locale = LocalePref.system,
    this.sourceFolders = const [],
    this.excludedFolders = const [],
    this.scanOnStartup = true,
    this.showHidden = false,
    this.crossfadeSeconds = 0,
    this.replayGain = ReplayGainMode.off,
    this.gapless = true,
    this.speedMemory = false,
    this.interruption = InterruptionBehavior.pause,
    this.lyricsAutoFetch = true,
    this.lyricsDefaultLanguage = 'auto',
    this.geniusApiKey = '',
    this.lastFmEnabled = false,
    this.androidAuto = true,
  });

  static const AppSettings defaults = AppSettings();

  final ThemePref themePref;
  final GlassIntensity glassIntensity;
  final bool dynamicColor;
  final double textScale;
  final DisplayDensity density;
  final LocalePref locale;

  final List<String> sourceFolders;
  final List<String> excludedFolders;
  final bool scanOnStartup;
  final bool showHidden;

  final double crossfadeSeconds;
  final ReplayGainMode replayGain;
  final bool gapless;
  final bool speedMemory;
  final InterruptionBehavior interruption;

  final bool lyricsAutoFetch;
  final String lyricsDefaultLanguage;
  final String geniusApiKey;

  final bool lastFmEnabled;
  final bool androidAuto;

  AppSettings copyWith({
    ThemePref? themePref,
    GlassIntensity? glassIntensity,
    bool? dynamicColor,
    double? textScale,
    DisplayDensity? density,
    LocalePref? locale,
    List<String>? sourceFolders,
    List<String>? excludedFolders,
    bool? scanOnStartup,
    bool? showHidden,
    double? crossfadeSeconds,
    ReplayGainMode? replayGain,
    bool? gapless,
    bool? speedMemory,
    InterruptionBehavior? interruption,
    bool? lyricsAutoFetch,
    String? lyricsDefaultLanguage,
    String? geniusApiKey,
    bool? lastFmEnabled,
    bool? androidAuto,
  }) {
    return AppSettings(
      themePref: themePref ?? this.themePref,
      glassIntensity: glassIntensity ?? this.glassIntensity,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      textScale: textScale ?? this.textScale,
      density: density ?? this.density,
      locale: locale ?? this.locale,
      sourceFolders: sourceFolders ?? this.sourceFolders,
      excludedFolders: excludedFolders ?? this.excludedFolders,
      scanOnStartup: scanOnStartup ?? this.scanOnStartup,
      showHidden: showHidden ?? this.showHidden,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      replayGain: replayGain ?? this.replayGain,
      gapless: gapless ?? this.gapless,
      speedMemory: speedMemory ?? this.speedMemory,
      interruption: interruption ?? this.interruption,
      lyricsAutoFetch: lyricsAutoFetch ?? this.lyricsAutoFetch,
      lyricsDefaultLanguage: lyricsDefaultLanguage ?? this.lyricsDefaultLanguage,
      geniusApiKey: geniusApiKey ?? this.geniusApiKey,
      lastFmEnabled: lastFmEnabled ?? this.lastFmEnabled,
      androidAuto: androidAuto ?? this.androidAuto,
    );
  }

  /// Serialises to a JSON-compatible map (settings backup export/import).
  Map<String, dynamic> toJson() => {
        'themePref': themePref.name,
        'glassIntensity': glassIntensity.name,
        'dynamicColor': dynamicColor,
        'textScale': textScale,
        'density': density.name,
        'locale': locale.name,
        'sourceFolders': sourceFolders,
        'excludedFolders': excludedFolders,
        'scanOnStartup': scanOnStartup,
        'showHidden': showHidden,
        'crossfadeSeconds': crossfadeSeconds,
        'replayGain': replayGain.name,
        'gapless': gapless,
        'speedMemory': speedMemory,
        'interruption': interruption.name,
        'lyricsAutoFetch': lyricsAutoFetch,
        'lyricsDefaultLanguage': lyricsDefaultLanguage,
        'geniusApiKey': geniusApiKey,
        'lastFmEnabled': lastFmEnabled,
        'androidAuto': androidAuto,
      };

  static AppSettings fromJson(Map<String, dynamic> json) {
    T enumOf<T>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if ((v as Enum).name == name) return v;
      }
      return fallback;
    }

    const d = AppSettings.defaults;
    return AppSettings(
      themePref: enumOf(ThemePref.values, json['themePref'], d.themePref),
      glassIntensity: enumOf(
          GlassIntensity.values, json['glassIntensity'], d.glassIntensity),
      dynamicColor: json['dynamicColor'] as bool? ?? d.dynamicColor,
      textScale: (json['textScale'] as num?)?.toDouble() ?? d.textScale,
      density: enumOf(DisplayDensity.values, json['density'], d.density),
      locale: enumOf(LocalePref.values, json['locale'], d.locale),
      sourceFolders:
          (json['sourceFolders'] as List?)?.cast<String>() ?? d.sourceFolders,
      excludedFolders: (json['excludedFolders'] as List?)?.cast<String>() ??
          d.excludedFolders,
      scanOnStartup: json['scanOnStartup'] as bool? ?? d.scanOnStartup,
      showHidden: json['showHidden'] as bool? ?? d.showHidden,
      crossfadeSeconds:
          (json['crossfadeSeconds'] as num?)?.toDouble() ?? d.crossfadeSeconds,
      replayGain: enumOf(ReplayGainMode.values, json['replayGain'], d.replayGain),
      gapless: json['gapless'] as bool? ?? d.gapless,
      speedMemory: json['speedMemory'] as bool? ?? d.speedMemory,
      interruption: enumOf(
          InterruptionBehavior.values, json['interruption'], d.interruption),
      lyricsAutoFetch: json['lyricsAutoFetch'] as bool? ?? d.lyricsAutoFetch,
      lyricsDefaultLanguage:
          json['lyricsDefaultLanguage'] as String? ?? d.lyricsDefaultLanguage,
      geniusApiKey: json['geniusApiKey'] as String? ?? d.geniusApiKey,
      lastFmEnabled: json['lastFmEnabled'] as bool? ?? d.lastFmEnabled,
      androidAuto: json['androidAuto'] as bool? ?? d.androidAuto,
    );
  }
}
