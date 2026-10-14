import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_policies.dart';
import 'connectivity_service.dart';
import 'consent_service.dart';

/// Central AdMob loader/shower. Never call from Flame update loops.
class AdMobService {
  AdMobService({
    required this.connectivity,
    ConsentService? consent,
    this.interstitialPolicy = const InterstitialPolicy(),
    this.appOpenPolicy = const AppOpenPolicy(),
  }) : consent = consent ?? ConsentService();

  final ConnectivityService connectivity;
  final ConsentService consent;
  final InterstitialPolicy interstitialPolicy;
  final AppOpenPolicy appOpenPolicy;

  bool _initialized = false;
  bool _showingAd = false;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadedAt;

  int _levelClearsSinceInterstitial = 0;
  bool _startupAppOpenConsumed = false;

  bool get isInitialized => _initialized;
  bool get isShowingAd => _showingAd;
  bool get isRewardedReady => _rewardedAd != null;
  bool get isInterstitialReady => _interstitialAd != null;
  bool get isAppOpenReady =>
      _appOpenAd != null &&
      appOpenPolicy.isFresh(_appOpenLoadedAt, DateTime.now());

  Future<void> initialize() async {
    if (_initialized) return;
    // google_mobile_ads is Android/iOS only — skip on Chrome/web.
    if (kIsWeb) {
      _initialized = true;
      debugPrint('AdMob skipped on web');
      return;
    }
    try {
      // UMP consent before Mobile Ads init (EEA/UK). Safe with test IDs.
      await consent.gatherConsent();
      final canAds = await consent.canRequestAds;
      if (!canAds) {
        debugPrint('Ads not allowed by consent yet');
      }
      await MobileAds.instance.initialize();
      if (AdConfig.useTestAds && AdConfig.testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: AdConfig.testDeviceIds),
        );
      }
      _initialized = true;
      if (canAds) {
        unawaited(preloadAll());
      }
    } catch (e, st) {
      debugPrint('AdMob init failed: $e\n$st');
    }
  }

  Future<void> preloadAll() async {
    await Future.wait([loadRewarded(), loadInterstitial(), loadAppOpen()]);
  }

  Future<void> loadRewarded() async {
    if (!_initialized) return;
    if (_rewardedAd != null) return;
    if (!await connectivity.refresh()) return;

    final completer = Completer<void>();
    await RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded failed: $error');
          _rewardedAd = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );
  }

  Future<void> loadInterstitial() async {
    if (!_initialized || !AdConfig.interstitialsEnabled) return;
    if (_interstitialAd != null) return;
    if (!await connectivity.refresh()) return;

    final completer = Completer<void>();
    await InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed: $error');
          _interstitialAd = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );
  }

  Future<void> loadAppOpen() async {
    if (!_initialized) return;
    if (_appOpenAd != null) return;
    if (!await connectivity.refresh()) return;

    final completer = Completer<void>();
    await AppOpenAd.load(
      adUnitId: AdConfig.appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadedAt = DateTime.now();
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpen failed: $error');
          _appOpenAd = null;
          _appOpenLoadedAt = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );
  }

  /// Generic rewarded placement (continue, 2x coins, daily double, streak save).
  Future<RewardedAdOutcome> showRewarded() => showRewardedContinue();

  /// Shows rewarded continue. Reward only when [OnUserEarnedRewardCallback] fires.
  Future<RewardedAdOutcome> showRewardedContinue() async {
    if (_showingAd) return RewardedAdOutcome.busy;
    if (!await connectivity.refresh(forceProbe: true)) {
      return RewardedAdOutcome.noInternet;
    }

    if (_rewardedAd == null) {
      await loadRewarded();
    }
    final ad = _rewardedAd;
    if (ad == null) {
      return _qaRewardOr(RewardedAdOutcome.failedToLoad);
    }

    _showingAd = true;
    _rewardedAd = null;
    final completer = Completer<RewardedAdOutcome>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingAd = false;
        unawaited(loadRewarded());
        if (!completer.isCompleted) {
          completer.complete(
            earned
                ? RewardedAdOutcome.rewarded
                : RewardedAdOutcome.dismissedWithoutReward,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded show failed: $error');
        ad.dispose();
        _showingAd = false;
        unawaited(loadRewarded());
        if (!completer.isCompleted) {
          completer.complete(_qaRewardOr(RewardedAdOutcome.failedToShow));
        }
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
        },
      );
    } catch (_) {
      _showingAd = false;
      ad.dispose();
      unawaited(loadRewarded());
      return _qaRewardOr(RewardedAdOutcome.failedToShow);
    }

    // B14: on timeout dispose the ad; never leave a second show unlocked
    // while the first fullscreen might still be visible.
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        try {
          ad.dispose();
        } catch (_) {}
        _showingAd = false;
        unawaited(loadRewarded());
        return earned
            ? RewardedAdOutcome.rewarded
            : RewardedAdOutcome.dismissedWithoutReward;
      },
    );
  }

  /// QA helper — grant reward when test ads cannot load (WebView/JS engine).
  RewardedAdOutcome _qaRewardOr(RewardedAdOutcome fallback) {
    if (AdConfig.useTestAds && AdConfig.qaSimulateRewardedWhenAdFails) {
      debugPrint('QA: simulating rewarded success (ad unavailable)');
      return RewardedAdOutcome.rewarded;
    }
    return fallback;
  }

  /// Cold-start only; once consumed, skip until next process start.
  Future<bool> showStartupAppOpenIfEligible() async {
    if (_startupAppOpenConsumed || _showingAd) return false;
    if (!await connectivity.refresh()) return false;
    if (!isAppOpenReady) {
      await loadAppOpen().timeout(const Duration(seconds: 6), onTimeout: () {});
    }
    if (!isAppOpenReady) return false;

    final ad = _appOpenAd!;
    _appOpenAd = null;
    _appOpenLoadedAt = null;
    _startupAppOpenConsumed = true;
    _showingAd = true;

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingAd = false;
        unawaited(loadAppOpen());
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showingAd = false;
        unawaited(loadAppOpen());
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show();
      await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {},
      );
      return true;
    } catch (_) {
      _showingAd = false;
      ad.dispose();
      return false;
    }
  }

  /// Call after a successful level clear (not section, not game-over).
  Future<bool> maybeShowInterstitialAfterLevelClear() async {
    _levelClearsSinceInterstitial += 1;
    if (_showingAd) return false;
    if (!interstitialPolicy.shouldShowAfterLevelClear(
      _levelClearsSinceInterstitial,
    )) {
      return false;
    }
    if (!await connectivity.refresh()) return false;
    if (_interstitialAd == null) {
      await loadInterstitial();
    }
    final ad = _interstitialAd;
    if (ad == null) return false;

    _interstitialAd = null;
    _showingAd = true;
    final completer = Completer<void>();
    var shownOk = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingAd = false;
        unawaited(loadInterstitial());
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showingAd = false;
        unawaited(loadInterstitial());
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show();
      shownOk = true;
      // B18: only reset frequency after a successful show() call.
      _levelClearsSinceInterstitial = 0;
      await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {},
      );
      return true;
    } catch (_) {
      _showingAd = false;
      if (!shownOk) {
        // Keep counter so the next clear can retry the interstitial slot.
      }
      try {
        ad.dispose();
      } catch (_) {}
      return false;
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _appOpenAd?.dispose();
    _rewardedAd = null;
    _interstitialAd = null;
    _appOpenAd = null;
  }
}
