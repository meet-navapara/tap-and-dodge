import 'ad_config.dart';

/// Pure rules for rewarded continues (unit-testable).
class RewardedContinuePolicy {
  const RewardedContinuePolicy({
    this.maxPerAttempt = AdConfig.maxRewardedContinuesPerAttempt,
  });

  final int maxPerAttempt;

  bool canContinue(int continuesUsedThisAttempt) =>
      continuesUsedThisAttempt < maxPerAttempt;

  int remaining(int continuesUsedThisAttempt) =>
      (maxPerAttempt - continuesUsedThisAttempt).clamp(0, maxPerAttempt);
}

/// Pure rules for interstitial frequency.
class InterstitialPolicy {
  const InterstitialPolicy({
    this.enabled = AdConfig.interstitialsEnabled,
    this.everyNClears = AdConfig.interstitialEveryNLevelClears,
  });

  final bool enabled;
  final int everyNClears;

  bool shouldShowAfterLevelClear(int clearsSinceLastInterstitial) {
    if (!enabled || everyNClears <= 0) return false;
    return clearsSinceLastInterstitial >= everyNClears;
  }
}

/// Result of attempting to show a rewarded ad.
enum RewardedAdOutcome {
  rewarded,
  dismissedWithoutReward,
  failedToLoad,
  failedToShow,
  noInternet,
  busy,
}

/// App-open eligibility helpers.
class AppOpenPolicy {
  const AppOpenPolicy({this.maxAge = const Duration(hours: 4)});

  final Duration maxAge;

  bool isFresh(DateTime? loadedAt, DateTime now) {
    if (loadedAt == null) return false;
    return now.difference(loadedAt) <= maxAge;
  }
}
