import '../../core/theme/glass_theme.dart';

enum ThemePref { system, light, dark, amoled }

enum ReplayGainMode { off, track, album }

enum InterruptionBehavior { pause, duck, ignore }

enum DisplayDensity { comfortable, standard, compact }

/// Selectable UI language; [system] follows the device locale.
enum LocalePref { system, en, fa, ar, de }

/// All user-facing preferences. Immutable; the [SettingsNotifier] swaps in new
/// instances and the [SettingsRepository] persists them.
class AppSettings {
  const AppSettings({
    this.themePref = ThemePref.amoled,
    this.glassIntensity = GlassIntensity.strong,
    this.dynamicColor = true,
    this.lightDance = true,
    this.textScale = 1.0,
    this.density = DisplayDensity.standard,
    this.locale = LocalePref.system,
    this.sourceFolders = const [],
    this.excludedFolders = const [],
    this.scanOnStartup = true,
    this.showHidden = false,
    this.hideDotFolders = true,
    this.minTrackSeconds = 0,
    this.allowSdCardEdit = false,
    this.crossfadeSeconds = 0,
    this.replayGain = ReplayGainMode.off,
    this.gapless = true,
    this.speedMemory = false,
    this.skipSilence = false,
    this.pitchSemitones = 0.0,
    this.interruption = InterruptionBehavior.pause,
    this.lyricsAutoFetch = true,
    this.lyricsDefaultLanguage = 'auto',
    this.geniusApiKey = '',
    this.lastFmEnabled = false,
    this.lastFmApiKey = '',
    this.lastFmApiSecret = '',
    this.lastFmSessionKey = '',
    this.lastFmUsername = '',
    this.androidAuto = true,
    this.onboardingSeen = false,
  });

  static const AppSettings defaults = AppSettings();

  final ThemePref themePref;
  final GlassIntensity glassIntensity;
  final bool dynamicColor;

  /// The Now Playing ambient light-dance (colour orbs swirling to the beat).
  /// When off, only a soft halo remains around the cover.
  final bool lightDance;
  final double textScale;
  final DisplayDensity density;
  final LocalePref locale;

  final List<String> sourceFolders;
  final List<String> excludedFolders;
  final bool scanOnStartup;
  final bool showHidden;

  /// Hide folders whose name begins with a dot (e.g. `.thumbnails`).
  final bool hideDotFolders;

  /// Drop tracks shorter than this many seconds (0 = keep everything).
  final int minTrackSeconds;

  /// Opt-in to file editing on removable storage (gates the broad-storage
  /// permission request; scoped read-only otherwise).
  final bool allowSdCardEdit;

  final double crossfadeSeconds;
  final ReplayGainMode replayGain;
  final bool gapless;
  final bool speedMemory;
  // Auto-skip silent sections during playback.
  final bool skipSilence;
  // Pitch shift in semitones; 0.0 = original.
  final double pitchSemitones;
  final InterruptionBehavior interruption;

  final bool lyricsAutoFetch;
  final String lyricsDefaultLanguage;
  final String geniusApiKey;

  final bool lastFmEnabled;
  final String lastFmApiKey;
  final String lastFmApiSecret;
  final String lastFmSessionKey;
  final String lastFmUsername;
  final bool androidAuto;
  final bool onboardingSeen;

  AppSettings copyWith({
    ThemePref? themePref,
    GlassIntensity? glassIntensity,
    bool? dynamicColor,
    bool? lightDance,
    double? textScale,
    DisplayDensity? density,
    LocalePref? locale,
    List<String>? sourceFolders,
    List<String>? excludedFolders,
    bool? scanOnStartup,
    bool? showHidden,
    bool? hideDotFolders,
    int? minTrackSeconds,
    bool? allowSdCardEdit,
    double? crossfadeSeconds,
    ReplayGainMode? replayGain,
    bool? gapless,
    bool? speedMemory,
    bool? skipSilence,
    double? pitchSemitones,
    InterruptionBehavior? interruption,
    bool? lyricsAutoFetch,
    String? lyricsDefaultLanguage,
    String? geniusApiKey,
    bool? lastFmEnabled,
    String? lastFmApiKey,
    String? lastFmApiSecret,
    String? lastFmSessionKey,
    String? lastFmUsername,
    bool? androidAuto,
    bool? onboardingSeen,
  }) {
    return AppSettings(
      themePref: themePref ?? this.themePref,
      glassIntensity: glassIntensity ?? this.glassIntensity,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      lightDance: lightDance ?? this.lightDance,
      textScale: textScale ?? this.textScale,
      density: density ?? this.density,
      locale: locale ?? this.locale,
      sourceFolders: sourceFolders ?? this.sourceFolders,
      excludedFolders: excludedFolders ?? this.excludedFolders,
      scanOnStartup: scanOnStartup ?? this.scanOnStartup,
      showHidden: showHidden ?? this.showHidden,
      hideDotFolders: hideDotFolders ?? this.hideDotFolders,
      minTrackSeconds: minTrackSeconds ?? this.minTrackSeconds,
      allowSdCardEdit: allowSdCardEdit ?? this.allowSdCardEdit,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      replayGain: replayGain ?? this.replayGain,
      gapless: gapless ?? this.gapless,
      speedMemory: speedMemory ?? this.speedMemory,
      skipSilence: skipSilence ?? this.skipSilence,
      pitchSemitones: pitchSemitones ?? this.pitchSemitones,
      interruption: interruption ?? this.interruption,
      lyricsAutoFetch: lyricsAutoFetch ?? this.lyricsAutoFetch,
      lyricsDefaultLanguage: lyricsDefaultLanguage ?? this.lyricsDefaultLanguage,
      geniusApiKey: geniusApiKey ?? this.geniusApiKey,
      lastFmEnabled: lastFmEnabled ?? this.lastFmEnabled,
      lastFmApiKey: lastFmApiKey ?? this.lastFmApiKey,
      lastFmApiSecret: lastFmApiSecret ?? this.lastFmApiSecret,
      lastFmSessionKey: lastFmSessionKey ?? this.lastFmSessionKey,
      lastFmUsername: lastFmUsername ?? this.lastFmUsername,
      androidAuto: androidAuto ?? this.androidAuto,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    );
  }

  /// Serialises to a JSON-compatible map (settings backup export/import).
  Map<String, dynamic> toJson() => {
        'themePref': themePref.name,
        'glassIntensity': glassIntensity.name,
        'dynamicColor': dynamicColor,
        'lightDance': lightDance,
        'textScale': textScale,
        'density': density.name,
        'locale': locale.name,
        'sourceFolders': sourceFolders,
        'excludedFolders': excludedFolders,
        'scanOnStartup': scanOnStartup,
        'showHidden': showHidden,
        'hideDotFolders': hideDotFolders,
        'minTrackSeconds': minTrackSeconds,
        'allowSdCardEdit': allowSdCardEdit,
        'crossfadeSeconds': crossfadeSeconds,
        'replayGain': replayGain.name,
        'gapless': gapless,
        'speedMemory': speedMemory,
        'skipSilence': skipSilence,
        'pitchSemitones': pitchSemitones,
        'interruption': interruption.name,
        'lyricsAutoFetch': lyricsAutoFetch,
        'lyricsDefaultLanguage': lyricsDefaultLanguage,
        'geniusApiKey': geniusApiKey,
        'lastFmEnabled': lastFmEnabled,
        'lastFmApiKey': lastFmApiKey,
        'lastFmApiSecret': lastFmApiSecret,
        'lastFmSessionKey': lastFmSessionKey,
        'lastFmUsername': lastFmUsername,
        'androidAuto': androidAuto,
        'onboardingSeen': onboardingSeen,
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
      lightDance: json['lightDance'] as bool? ?? d.lightDance,
      textScale: (json['textScale'] as num?)?.toDouble() ?? d.textScale,
      density: enumOf(DisplayDensity.values, json['density'], d.density),
      locale: enumOf(LocalePref.values, json['locale'], d.locale),
      sourceFolders:
          (json['sourceFolders'] as List?)?.cast<String>() ?? d.sourceFolders,
      excludedFolders: (json['excludedFolders'] as List?)?.cast<String>() ??
          d.excludedFolders,
      scanOnStartup: json['scanOnStartup'] as bool? ?? d.scanOnStartup,
      showHidden: json['showHidden'] as bool? ?? d.showHidden,
      hideDotFolders: json['hideDotFolders'] as bool? ?? d.hideDotFolders,
      minTrackSeconds: (json['minTrackSeconds'] as num?)?.toInt() ??
          d.minTrackSeconds,
      allowSdCardEdit: json['allowSdCardEdit'] as bool? ?? d.allowSdCardEdit,
      crossfadeSeconds:
          (json['crossfadeSeconds'] as num?)?.toDouble() ?? d.crossfadeSeconds,
      replayGain: enumOf(ReplayGainMode.values, json['replayGain'], d.replayGain),
      gapless: json['gapless'] as bool? ?? d.gapless,
      speedMemory: json['speedMemory'] as bool? ?? d.speedMemory,
      skipSilence: json['skipSilence'] as bool? ?? d.skipSilence,
      pitchSemitones: (json['pitchSemitones'] as num?)?.toDouble() ?? d.pitchSemitones,
      interruption: enumOf(
          InterruptionBehavior.values, json['interruption'], d.interruption),
      lyricsAutoFetch: json['lyricsAutoFetch'] as bool? ?? d.lyricsAutoFetch,
      lyricsDefaultLanguage:
          json['lyricsDefaultLanguage'] as String? ?? d.lyricsDefaultLanguage,
      geniusApiKey: json['geniusApiKey'] as String? ?? d.geniusApiKey,
      lastFmEnabled: json['lastFmEnabled'] as bool? ?? d.lastFmEnabled,
      lastFmApiKey: json['lastFmApiKey'] as String? ?? d.lastFmApiKey,
      lastFmApiSecret: json['lastFmApiSecret'] as String? ?? d.lastFmApiSecret,
      lastFmSessionKey: json['lastFmSessionKey'] as String? ?? d.lastFmSessionKey,
      lastFmUsername: json['lastFmUsername'] as String? ?? d.lastFmUsername,
      androidAuto: json['androidAuto'] as bool? ?? d.androidAuto,
      onboardingSeen: json['onboardingSeen'] as bool? ?? d.onboardingSeen,
    );
  }
}
