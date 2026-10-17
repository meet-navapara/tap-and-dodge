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
  Future<void>? _initFuture;
  Future<void>? _preloadFuture;
  Future<void> _loadChain = Future.value();

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

  /// Safe to call from UI — waits for in-flight init and retries if needed.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await initialize();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    _initFuture = _doInitialize();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _doInitialize() async {
    if (_initialized) return;
    // google_mobile_ads is Android/iOS only — skip on Chrome/web.
    if (kIsWeb) {
      _initialized = true;
      debugPrint('AdMob skipped on web');
      return;
    }
    // Prevent shipping Google sample / test AdMob IDs in a Play release build.
    if (kReleaseMode && AdConfig.useTestAds) {
      throw StateError(
        'AdConfig.useTestAds is true in a release build. '
        'Paste production AdMob IDs and set useTestAds=false before Play upload.',
      );
    }
    if (kReleaseMode &&
        (AdConfig.productionAndroidAppId.contains('xxxx') ||
            AdConfig.productionIosAppId.contains('xxxx') ||
            AdConfig.productionRewardedUnitId.contains('xxxx') ||
            AdConfig.productionIosRewardedUnitId.contains('xxxx'))) {
      throw StateError(
        'Production AdMob unit IDs are still placeholders. '
        'Replace them in ad_config.dart before store upload.',
      );
    }
    try {
      // UMP consent before Mobile Ads init (EEA/UK). Safe with test IDs.
      await consent.gatherConsent();
      final canAds = await consent.canRequestAds;
      debugPrint('AdMob canRequestAds=$canAds useTestAds=${AdConfig.useTestAds}');

      await MobileAds.instance.initialize();

      // Always register test devices in debug so physical phones get test ads.
      if (!kReleaseMode && AdConfig.testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: AdConfig.testDeviceIds),
        );
      }

      _initialized = true;
      debugPrint(
        'AdMob initialized · rewarded=${AdConfig.rewardedUnitId}',
      );

      // With Google test IDs, still preload even if UMP is undecided —
      // otherwise rewarded taps race ahead of a cold SDK and never show.
      if (canAds || AdConfig.useTestAds) {
        // WebView / JavascriptEngine is often not ready on cold start.
        // MainActivity also warms WebView; still delay before first request.
        unawaited(() async {
          // Give MainActivity WebView warmup a moment to boot Chromium.
          await Future<void>.delayed(const Duration(milliseconds: 800));
          await preloadAll();
        }());
      } else {
        debugPrint('Ads not allowed by consent yet — skipping preload');
      }
    } catch (e, st) {
      debugPrint('AdMob init failed: $e\n$st');
    }
  }

  /// Single-flight, **sequential** preload — parallel loads starve WebView
  /// and cause "Unable to obtain a JavascriptEngine" on many Pixels.
  Future<void> preloadAll() async {
    if (_preloadFuture != null) return _preloadFuture!;
    _preloadFuture = () async {
      await loadRewarded(retries: 5);
      await loadInterstitial(retries: 3);
      await loadAppOpen(retries: 3);
    }();
    try {
      await _preloadFuture;
    } finally {
      _preloadFuture = null;
    }
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final next = _loadChain.then((_) => action());
    _loadChain = next.then((_) {}, onError: (_) {});
    return next;
  }

  bool _isWebViewNotReady(LoadAdError error) {
    final msg = error.message.toLowerCase();
    return msg.contains('javascriptengine') || msg.contains('webview');
  }

  Duration _retryDelay(int attempt, {required bool webViewIssue}) {
    if (webViewIssue) {
      // WebView needs longer to come up after process start.
      return Duration(milliseconds: 1200 * (attempt + 1));
    }
    return Duration(milliseconds: 500 * (attempt + 1));
  }

  Future<void> loadRewarded({int retries = 1}) {
    return _serialized(() => _loadRewardedBody(retries: retries));
  }

  Future<void> _loadRewardedBody({int retries = 1}) async {
    await ensureInitialized();
    if (!_initialized) return;
    if (_rewardedAd != null) return;

    for (var attempt = 0; attempt <= retries; attempt++) {
      final completer = Completer<(bool, LoadAdError?)>();
      try {
        await RewardedAd.load(
          adUnitId: AdConfig.rewardedUnitId,
          request: const AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              _rewardedAd = ad;
              debugPrint('Rewarded ad loaded');
              if (!completer.isCompleted) completer.complete((true, null));
            },
            onAdFailedToLoad: (error) {
              debugPrint(
                'Rewarded failed (attempt ${attempt + 1}): '
                '${error.code} ${error.message}',
              );
              _rewardedAd = null;
              if (!completer.isCompleted) completer.complete((false, error));
            },
          ),
        );
      } catch (e, st) {
        debugPrint('Rewarded load threw: $e\n$st');
        if (!completer.isCompleted) completer.complete((false, null));
      }

      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Rewarded load timed out');
          return (false, null);
        },
      );
      if (result.$1 || _rewardedAd != null) return;
      if (attempt < retries) {
        final webViewIssue =
            result.$2 != null && _isWebViewNotReady(result.$2!);
        await Future<void>.delayed(
          _retryDelay(attempt, webViewIssue: webViewIssue),
        );
      }
    }
  }

  Future<void> loadInterstitial({int retries = 1}) {
    return _serialized(() => _loadInterstitialBody(retries: retries));
  }

  Future<void> _loadInterstitialBody({int retries = 1}) async {
    await ensureInitialized();
    if (!_initialized || !AdConfig.interstitialsEnabled) return;
    if (_interstitialAd != null) return;

    for (var attempt = 0; attempt <= retries; attempt++) {
      final completer = Completer<(bool, LoadAdError?)>();
      try {
        await InterstitialAd.load(
          adUnitId: AdConfig.interstitialUnitId,
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              _interstitialAd = ad;
              debugPrint('Interstitial ad loaded');
              if (!completer.isCompleted) completer.complete((true, null));
            },
            onAdFailedToLoad: (error) {
              debugPrint(
                'Interstitial failed (attempt ${attempt + 1}): '
                '${error.code} ${error.message}',
              );
              _interstitialAd = null;
              if (!completer.isCompleted) completer.complete((false, error));
            },
          ),
        );
      } catch (e, st) {
        debugPrint('Interstitial load threw: $e\n$st');
        if (!completer.isCompleted) completer.complete((false, null));
      }

      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => (false, null),
      );
      if (result.$1 || _interstitialAd != null) return;
      if (attempt < retries) {
        final webViewIssue =
            result.$2 != null && _isWebViewNotReady(result.$2!);
        await Future<void>.delayed(
          _retryDelay(attempt, webViewIssue: webViewIssue),
        );
      }
    }
  }

  Future<void> loadAppOpen({int retries = 1}) {
    return _serialized(() => _loadAppOpenBody(retries: retries));
  }

  Future<void> _loadAppOpenBody({int retries = 1}) async {
    await ensureInitialized();
    if (!_initialized) return;
    if (_appOpenAd != null) return;

    for (var attempt = 0; attempt <= retries; attempt++) {
      final completer = Completer<(bool, LoadAdError?)>();
      try {
        await AppOpenAd.load(
          adUnitId: AdConfig.appOpenUnitId,
          request: const AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) {
              _appOpenAd = ad;
              _appOpenLoadedAt = DateTime.now();
              debugPrint('AppOpen ad loaded');
              if (!completer.isCompleted) completer.complete((true, null));
            },
            onAdFailedToLoad: (error) {
              debugPrint(
                'AppOpen failed (attempt ${attempt + 1}): '
                '${error.code} ${error.message}',
              );
              _appOpenAd = null;
              _appOpenLoadedAt = null;
              if (!completer.isCompleted) completer.complete((false, error));
            },
          ),
        );
      } catch (e, st) {
        debugPrint('AppOpen load threw: $e\n$st');
        if (!completer.isCompleted) completer.complete((false, null));
      }

      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => (false, null),
      );
      if (result.$1 || _appOpenAd != null) return;
      if (attempt < retries) {
        final webViewIssue =
            result.$2 != null && _isWebViewNotReady(result.$2!);
        await Future<void>.delayed(
          _retryDelay(attempt, webViewIssue: webViewIssue),
        );
      }
    }
  }

  /// Generic rewarded placement (continue, 2x coins, daily double, streak save).
  Future<RewardedAdOutcome> showRewarded() => showRewardedContinue();

  /// Shows rewarded continue. Reward only when [OnUserEarnedRewardCallback] fires.
  Future<RewardedAdOutcome> showRewardedContinue() async {
    if (_showingAd) return RewardedAdOutcome.busy;
    await ensureInitialized();
    if (!_initialized) {
      debugPrint('Rewarded show aborted — AdMob not initialized');
      return _qaRewardOr(RewardedAdOutcome.failedToLoad);
    }

    final online = await connectivity.refresh(forceProbe: true);
    if (_rewardedAd == null) {
      await loadRewarded(retries: 2);
    }
    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint('Rewarded show aborted — no ad loaded (online=$online)');
      // Only report no-internet when probe failed AND load failed.
      if (!online) return RewardedAdOutcome.noInternet;
      return _qaRewardOr(RewardedAdOutcome.failedToLoad);
    }

    _showingAd = true;
    _rewardedAd = null;
    final completer = Completer<RewardedAdOutcome>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Rewarded ad showing');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingAd = false;
        unawaited(loadRewarded(retries: 1));
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
        unawaited(loadRewarded(retries: 1));
        if (!completer.isCompleted) {
          completer.complete(_qaRewardOr(RewardedAdOutcome.failedToShow));
        }
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
          debugPrint('Rewarded earned: ${reward.amount} ${reward.type}');
        },
      );
    } catch (e, st) {
      debugPrint('Rewarded show threw: $e\n$st');
      _showingAd = false;
      ad.dispose();
      unawaited(loadRewarded(retries: 1));
      return _qaRewardOr(RewardedAdOutcome.failedToShow);
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        try {
          ad.dispose();
        } catch (_) {}
        _showingAd = false;
        unawaited(loadRewarded(retries: 1));
        return earned
            ? RewardedAdOutcome.rewarded
            : RewardedAdOutcome.dismissedWithoutReward;
      },
    );
  }

  /// QA helper — grant reward when test ads cannot load/show (WebView/JS engine).
  /// Disabled in release to avoid AdMob invalid-traffic / deceptive-reward policy hits.
  RewardedAdOutcome _qaRewardOr(RewardedAdOutcome fallback) {
    if (!kReleaseMode &&
        AdConfig.useTestAds &&
        AdConfig.qaSimulateRewardedWhenAdFails) {
      debugPrint('QA: simulating rewarded success (ad unavailable)');
      return RewardedAdOutcome.rewarded;
    }
    return fallback;
  }

  /// Cold-start only; once consumed, skip until next process start.
  Future<bool> showStartupAppOpenIfEligible() async {
    if (_startupAppOpenConsumed || _showingAd) return false;
    await ensureInitialized();
    if (!_initialized) return false;
    if (!isAppOpenReady) {
      await loadAppOpen(retries: 1).timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
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
        unawaited(loadAppOpen(retries: 1));
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpen show failed: $error');
        ad.dispose();
        _showingAd = false;
        unawaited(loadAppOpen(retries: 1));
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
    await ensureInitialized();
    if (!_initialized) return false;
    if (_interstitialAd == null) {
      await loadInterstitial(retries: 1);
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
        unawaited(loadInterstitial(retries: 1));
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial show failed: $error');
        ad.dispose();
        _showingAd = false;
        unawaited(loadInterstitial(retries: 1));
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show();
      shownOk = true;
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
