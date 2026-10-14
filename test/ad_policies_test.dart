import 'package:flutter_test/flutter_test.dart';
import 'package:tap_and_dodge/services/ad_policies.dart';

void main() {
  group('RewardedContinuePolicy', () {
    test('allows one continue then blocks', () {
      const policy = RewardedContinuePolicy(maxPerAttempt: 1);
      expect(policy.canContinue(0), isTrue);
      expect(policy.canContinue(1), isFalse);
      expect(policy.remaining(0), 1);
      expect(policy.remaining(1), 0);
    });
  });

  group('InterstitialPolicy', () {
    test('respects frequency and disable flag', () {
      const policy = InterstitialPolicy(enabled: true, everyNClears: 3);
      expect(policy.shouldShowAfterLevelClear(0), isFalse);
      expect(policy.shouldShowAfterLevelClear(2), isFalse);
      expect(policy.shouldShowAfterLevelClear(3), isTrue);

      const off = InterstitialPolicy(enabled: false, everyNClears: 1);
      expect(off.shouldShowAfterLevelClear(5), isFalse);
    });
  });

  group('AppOpenPolicy', () {
    test('freshness window', () {
      const policy = AppOpenPolicy(maxAge: Duration(hours: 4));
      final now = DateTime(2026, 1, 1, 12);
      expect(policy.isFresh(null, now), isFalse);
      expect(
        policy.isFresh(now.subtract(const Duration(hours: 3)), now),
        isTrue,
      );
      expect(
        policy.isFresh(now.subtract(const Duration(hours: 5)), now),
        isFalse,
      );
    });
  });

  group('RewardedAdOutcome', () {
    test('rewarded is distinct from dismiss', () {
      expect(
        RewardedAdOutcome.rewarded == RewardedAdOutcome.dismissedWithoutReward,
        isFalse,
      );
    });
  });
}
