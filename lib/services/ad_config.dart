import 'package:flutter/foundation.dart';

/// AdMob IDs and monetization policy knobs.
///
/// Development uses Google's official test IDs. Before publishing, replace
/// [useTestAds] / production placeholders with your AdMob console values.
class AdConfig {
  const AdConfig._();

  /// Keep `true` until you paste real AdMob IDs.
  /// Release builds refuse to start ads while this is true (AdMob invalid-traffic risk).
  static const bool useTestAds = true;

  /// Debug/QA only: when test ads fail to load/show, grant the reward so device
  /// QA can verify continue / 2x / daily double. Never active in release builds.
  static const bool qaSimulateRewardedWhenAdFails = true;

  /// AdMob test device IDs (from logcat / Xcode console).
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

  // ── Google official test App IDs ─────────────────────────────────────────
  static const String testAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String testIosAppId = 'ca-app-pub-3940256099942544~1458002511';

  // ── Google official Android/iOS test unit IDs ────────────────────────────
  static const String testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testIosRewardedUnitId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testIosInterstitialUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String testAppOpenUnitId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String testIosAppOpenUnitId =
      'ca-app-pub-3940256099942544/5576995850';

  // ── Production placeholders (replace before release) ─────────────────────
  static const String productionAndroidAppId =
      'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy';
  static const String productionIosAppId =
      'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy';
  static const String productionRewardedUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';
  static const String productionIosRewardedUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';
  static const String productionInterstitialUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';
  static const String productionIosInterstitialUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';
  static const String productionAppOpenUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';
  static const String productionIosAppOpenUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz';

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static String get androidAppId =>
      useTestAds ? testAndroidAppId : productionAndroidAppId;

  static String get iosAppId => useTestAds ? testIosAppId : productionIosAppId;

  static String get rewardedUnitId {
    if (_isIos) {
      return useTestAds ? testIosRewardedUnitId : productionIosRewardedUnitId;
    }
    return useTestAds ? testRewardedUnitId : productionRewardedUnitId;
  }

  static String get interstitialUnitId {
    if (_isIos) {
      return useTestAds
          ? testIosInterstitialUnitId
          : productionIosInterstitialUnitId;
    }
    return useTestAds ? testInterstitialUnitId : productionInterstitialUnitId;
  }

  static String get appOpenUnitId {
    if (_isIos) {
      return useTestAds ? testIosAppOpenUnitId : productionIosAppOpenUnitId;
    }
    return useTestAds ? testAppOpenUnitId : productionAppOpenUnitId;
  }
}
