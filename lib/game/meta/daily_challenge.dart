import '../../services/ad_config.dart';

/// Pure helpers for daily challenge + streak (unit-testable).
class DailyChallengeLogic {
  static const baseRewardCoins = 25;
  static const doubleRewardCoins = 25;

  /// Stable calendar day key in local time: YYYY-MM-DD
  static String dayKey(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseDayKey(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static int daysBetween(String earlier, String later) {
    final a = parseDayKey(earlier);
    final b = parseDayKey(later);
    return b.difference(a).inDays;
  }

  /// Pick a challenge level within unlocked range (1..unlocked).
  static int challengeLevelForDay(String day, int unlockedLevel) {
    final unlocked = unlockedLevel.clamp(1, 50);
    var hash = 0;
    for (final c in day.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return 1 + (hash % unlocked);
  }

  static int nextStreak({
    required int currentStreak,
    required String? lastClaimDay,
    required String today,
  }) {
    if (lastClaimDay == null) return 1;
    if (lastClaimDay == today) return currentStreak;
    final gap = daysBetween(lastClaimDay, today);
    if (gap == 1) return currentStreak + 1;
    return 1;
  }

  /// Missed exactly one day → streak can still be saved by ad.
  static bool canSaveStreak({
    required int currentStreak,
    required String? lastClaimDay,
    required String today,
    required bool alreadySavedToday,
  }) {
    if (alreadySavedToday || currentStreak <= 0 || lastClaimDay == null) {
      return false;
    }
    return daysBetween(lastClaimDay, today) == 2;
  }
}

/// Lightweight knobs for meta rewards.
class MetaRewards {
  static const int dailyBase = DailyChallengeLogic.baseRewardCoins;
  static const int dailyDouble = DailyChallengeLogic.doubleRewardCoins;
  static const int streakSaveUsesRewardedAd = 1;
  static bool get doubleCoinsAdEnabled => true;
  static int get maxRewardedContinues =>
      AdConfig.maxRewardedContinuesPerAttempt;
}
