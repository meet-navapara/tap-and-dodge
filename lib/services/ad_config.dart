/// AdMob IDs and monetization policy knobs.
///
/// Development uses Google's official test IDs. Before publishing, replace
/// [useTestAds] / production placeholders with your AdMob console values.
class AdConfig {
  const AdConfig._();

  /// Keep `true` until you paste real AdMob IDs (deferred — do before Play publish).
  static const bool useTestAds = true;

  /// When test ads fail to load/show, still grant the reward so QA can verify
  /// continue / 2x coins / daily double without a working WebView ad engine.
  /// Set `false` before shipping with real ads.
  static const bool qaSimulateRewardedWhenAdFails = true;

  /// AdMob test device IDs (from logcat: "Use RequestConfiguration...").
  static const List<String> testDeviceIds = [
    'D9A77BFA8C8A339A99ACA839A33FC145',
    'CFCCAF98C06E73CF5908B36059D33E73',
  ];

  /// Interstitials after level clear (configurable).
  static const bool interstitialsEnabled = true;

  /// Show an interstitial after this many successful level clears.
  static const int interstitialEveryNLevelClears = 3;

  /// Max rewarded continues per level attempt.
  static const int maxRewardedContinuesPerAttempt = 1;

  /// App-open freshness window (hours) per Google guidance.
  static const int appOpenMaxAgeHours = 4;

  // ── Google official Android test IDs ─────────────────────────────────────
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testAppOpenUnitId =
      'ca-app-pub-3940256099942544/9257395921';

  // ── Production placeholders (replace before release) ─────────────────────
  static const String productionAppId =
      'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy';
  static const String productionRewardedUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';
  static const String productionInterstitialUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';
  static const String productionAppOpenUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';

  static String get androidAppId => useTestAds ? testAppId : productionAppId;

  static String get rewardedUnitId =>
      useTestAds ? testRewardedUnitId : productionRewardedUnitId;

  static String get interstitialUnitId =>
      useTestAds ? testInterstitialUnitId : productionInterstitialUnitId;

  static String get appOpenUnitId =>
      useTestAds ? testAppOpenUnitId : productionAppOpenUnitId;
}
