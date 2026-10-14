import 'package:shared_preferences/shared_preferences.dart';

import '../game/campaign/campaign_catalog.dart';
import '../game/campaign/campaign_progress.dart';
import '../game/meta/daily_challenge.dart';
import '../game/meta/ship_skins.dart';
import 'player_progress.dart';

/// Local persistence for score, coins, campaign unlocks, and meta economy.
class ScoreService {
  ScoreService({this._prefs});

  static const _bestScoreKey = 'tap_dodge_best_score';
  static const _totalCoinsKey = 'tap_dodge_total_coins';
  static const _unlockedLevelKey = 'tap_dodge_unlocked_level_v2';
  static const _completedLevelKey = 'tap_dodge_completed_level_v2';
  static const _legacyUnlockedKey = 'tap_dodge_unlocked_level';
  static const _legacyCompletedKey = 'tap_dodge_completed_level';
  static const _levelBestPrefix = 'tap_dodge_level_best_';
  static const _campaignCompleteKey = 'tap_dodge_campaign_complete';
  static const _worldRewardPrefix = 'tap_dodge_world_cleared_';
  static const _streakKey = 'tap_dodge_streak';
  static const _lastDailyClaimKey = 'tap_dodge_last_daily_claim';
  static const _dailyDoubleKey = 'tap_dodge_daily_double_day';
  static const _streakSaveKey = 'tap_dodge_streak_save_day';
  static const _ownedSkinsKey = 'tap_dodge_owned_skins';
  static const _equippedSkinKey = 'tap_dodge_equipped_skin';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _migrateLegacyProgress();
  }

  Future<void> _migrateLegacyProgress() async {
    final unlocked = _prefs!.getInt(_unlockedLevelKey);
    if (unlocked != null) return;
    final legacyUnlocked = _prefs!.getInt(_legacyUnlockedKey) ?? 1;
    final legacyCompleted = _prefs!.getInt(_legacyCompletedKey) ?? 0;
    await _prefs!.setInt(
      _unlockedLevelKey,
      CampaignProgress.sanitizeUnlocked(legacyUnlocked),
    );
    await _prefs!.setInt(
      _completedLevelKey,
      CampaignProgress.sanitizeCompleted(legacyCompleted),
    );
  }

  int get bestScore => _prefs?.getInt(_bestScoreKey) ?? 0;

  int get totalCoins => _prefs?.getInt(_totalCoinsKey) ?? 0;

  int get unlockedLevel =>
      CampaignProgress.sanitizeUnlocked(_prefs?.getInt(_unlockedLevelKey) ?? 1);

  int get highestCompletedLevel => CampaignProgress.sanitizeCompleted(
    _prefs?.getInt(_completedLevelKey) ?? 0,
  );

  bool get isCampaignComplete =>
      _prefs?.getBool(_campaignCompleteKey) == true ||
      CampaignProgress.isCampaignComplete(highestCompletedLevel);

  int bestScoreForLevel(int level) =>
      _prefs?.getInt('$_levelBestPrefix$level') ?? 0;

  Future<int> submitScore(int score) async {
    await init();
    final currentBest = bestScore;
    if (score > currentBest) {
      await _prefs!.setInt(_bestScoreKey, score);
      return score;
    }
    return currentBest;
  }

  Future<void> submitLevelScore(int level, int score) async {
    await init();
    final key = '$_levelBestPrefix$level';
    final prev = _prefs!.getInt(key) ?? 0;
    if (score > prev) {
      await _prefs!.setInt(key, score);
    }
    await submitScore(score);
  }

  Future<int> addCoins(int amount) async {
    await init();
    if (amount <= 0) return totalCoins;
    final next = totalCoins + amount;
    await _prefs!.setInt(_totalCoinsKey, next);
    return next;
  }

  /// Marks a campaign level complete and unlocks the next one (never past 50).
  ///
  /// Returns the completion coin bonus actually granted (0 on replay).
  Future<int> completeLevel(
    int levelNumber, {
    required int coinReward,
    int score = 0,
  }) async {
    await init();
    final completed = CampaignProgress.sanitizeCompleted(levelNumber);
    final isFirstClear = completed > highestCompletedLevel;
    if (isFirstClear) {
      await _prefs!.setInt(_completedLevelKey, completed);
    }
    final unlocked = CampaignProgress.nextUnlockedAfter(
      completed,
      unlockedLevel,
    );
    await _prefs!.setInt(_unlockedLevelKey, unlocked);
    var granted = 0;
    if (isFirstClear && coinReward > 0) {
      await addCoins(coinReward);
      granted = coinReward;
    }
    if (score > 0) {
      await submitLevelScore(levelNumber, score);
    }
    if (completed >= CampaignCatalog.maxLevel) {
      await _prefs!.setBool(_campaignCompleteKey, true);
    }
    return granted;
  }

  bool isWorldRewardClaimed(int worldIndex) =>
      _prefs?.getBool('$_worldRewardPrefix$worldIndex') == true;

  /// Grants a one-time world milestone reward. Returns coins granted (0 if claimed).
  Future<int> grantWorldReward(
    int worldIndex, {
    required int coinReward,
  }) async {
    await init();
    final key = '$_worldRewardPrefix$worldIndex';
    if (_prefs!.getBool(key) == true || coinReward <= 0) return 0;
    await _prefs!.setBool(key, true);
    await addCoins(coinReward);
    return coinReward;
  }

  Future<void> resetBestScore() async {
    await init();
    await _prefs!.remove(_bestScoreKey);
  }

  Future<bool> spendCoins(int amount) async {
    await init();
    if (amount <= 0 || totalCoins < amount) return false;
    await _prefs!.setInt(_totalCoinsKey, totalCoins - amount);
    return true;
  }

  // ── Daily challenge / streak ─────────────────────────────────────────────

  int get streak => _prefs?.getInt(_streakKey) ?? 0;

  String? get lastDailyClaimDay => _prefs?.getString(_lastDailyClaimKey);

  String get todayKey => DailyChallengeLogic.dayKey(DateTime.now());

  bool get hasClaimedDailyToday => lastDailyClaimDay == todayKey;

  bool get hasClaimedDailyDoubleToday =>
      _prefs?.getString(_dailyDoubleKey) == todayKey;

  bool get hasSavedStreakToday => _prefs?.getString(_streakSaveKey) == todayKey;

  int get todaysChallengeLevel =>
      DailyChallengeLogic.challengeLevelForDay(todayKey, unlockedLevel);

  bool get canSaveStreak => DailyChallengeLogic.canSaveStreak(
    currentStreak: streak,
    lastClaimDay: lastDailyClaimDay,
    today: todayKey,
    alreadySavedToday: hasSavedStreakToday,
  );

  /// Claims the free daily reward. Returns coins granted (0 if already claimed).
  Future<int> claimDailyReward() async {
    await init();
    if (hasClaimedDailyToday) return 0;
    final today = todayKey;
    final next = DailyChallengeLogic.nextStreak(
      currentStreak: streak,
      lastClaimDay: lastDailyClaimDay,
      today: today,
    );
    await _prefs!.setInt(_streakKey, next);
    await _prefs!.setString(_lastDailyClaimKey, today);
    await addCoins(DailyChallengeLogic.baseRewardCoins);
    return DailyChallengeLogic.baseRewardCoins;
  }

  /// Second daily payout after a rewarded ad (once per day).
  Future<int> claimDailyDoubleReward() async {
    await init();
    if (!hasClaimedDailyToday || hasClaimedDailyDoubleToday) return 0;
    await _prefs!.setString(_dailyDoubleKey, todayKey);
    await addCoins(DailyChallengeLogic.doubleRewardCoins);
    return DailyChallengeLogic.doubleRewardCoins;
  }

  /// Prevents streak reset when the player missed exactly one day.
  Future<bool> saveStreakWithAd() async {
    await init();
    if (!canSaveStreak) return false;
    // B12: never rewrite today's claim marker after a successful claim.
    if (hasClaimedDailyToday) return false;
    await _prefs!.setString(_streakSaveKey, todayKey);
    // Pretend they claimed yesterday so today's claim continues the chain.
    // B13: calendar yesterday (not 24h subtract) for DST safety.
    final now = DateTime.now().toLocal();
    final yesterday = DailyChallengeLogic.dayKey(
      DateTime(now.year, now.month, now.day - 1),
    );
    await _prefs!.setString(_lastDailyClaimKey, yesterday);
    return true;
  }

  // ── Ship skins ───────────────────────────────────────────────────────────

  Set<String> get ownedSkinIds {
    final raw = _prefs?.getStringList(_ownedSkinsKey) ?? const [];
    return {ShipSkinCatalog.defaultId, ...raw};
  }

  String get equippedSkinId =>
      _prefs?.getString(_equippedSkinKey) ?? ShipSkinCatalog.defaultId;

  ShipSkin get equippedSkin => ShipSkinCatalog.byId(equippedSkinId);

  bool ownsSkin(String id) => ownedSkinIds.contains(id);

  Future<bool> purchaseSkin(String id) async {
    await init();
    final skin = ShipSkinCatalog.byId(id);
    if (ownsSkin(id)) return true;
    if (skin.cost <= 0) {
      await _unlockSkin(id);
      return true;
    }
    if (!await spendCoins(skin.cost)) return false;
    await _unlockSkin(id);
    return true;
  }

  Future<void> equipSkin(String id) async {
    await init();
    if (!ownsSkin(id)) return;
    await _prefs!.setString(_equippedSkinKey, id);
  }

  Future<void> _unlockSkin(String id) async {
    final next = ownedSkinIds.toList()..add(id);
    await _prefs!.setStringList(_ownedSkinsKey, next.toSet().toList());
  }

  // ── Cloud sync helpers ───────────────────────────────────────────────────

  PlayerProgress exportProgress() {
    final levelBests = <String, int>{};
    final worlds = <int>[];
    for (var level = 1; level <= CampaignCatalog.maxLevel; level++) {
      final best = bestScoreForLevel(level);
      if (best > 0) levelBests['$level'] = best;
    }
    for (var w = 0; w < CampaignCatalog.worldCount; w++) {
      if (isWorldRewardClaimed(w)) worlds.add(w);
    }
    return PlayerProgress(
      schemaVersion: PlayerProgress.currentSchemaVersion,
      bestScore: bestScore,
      totalCoins: totalCoins,
      unlockedLevel: unlockedLevel,
      highestCompletedLevel: highestCompletedLevel,
      campaignComplete: isCampaignComplete,
      streak: streak,
      lastDailyClaimDay: lastDailyClaimDay,
      dailyDoubleDay: _prefs?.getString(_dailyDoubleKey),
      streakSaveDay: _prefs?.getString(_streakSaveKey),
      ownedSkinIds: ownedSkinIds.toList(),
      equippedSkinId: equippedSkinId,
      worldRewardsClaimed: worlds,
      levelBests: levelBests,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> importProgress(PlayerProgress data) async {
    await init();
    await _prefs!.setInt(_bestScoreKey, data.bestScore);
    await _prefs!.setInt(_totalCoinsKey, data.totalCoins);
    await _prefs!.setInt(
      _unlockedLevelKey,
      CampaignProgress.sanitizeUnlocked(data.unlockedLevel),
    );
    await _prefs!.setInt(
      _completedLevelKey,
      CampaignProgress.sanitizeCompleted(data.highestCompletedLevel),
    );
    await _prefs!.setBool(_campaignCompleteKey, data.campaignComplete);
    await _prefs!.setInt(_streakKey, data.streak);
    if (data.lastDailyClaimDay != null) {
      await _prefs!.setString(_lastDailyClaimKey, data.lastDailyClaimDay!);
    } else {
      await _prefs!.remove(_lastDailyClaimKey);
    }
    if (data.dailyDoubleDay != null) {
      await _prefs!.setString(_dailyDoubleKey, data.dailyDoubleDay!);
    } else {
      await _prefs!.remove(_dailyDoubleKey);
    }
    if (data.streakSaveDay != null) {
      await _prefs!.setString(_streakSaveKey, data.streakSaveDay!);
    } else {
      await _prefs!.remove(_streakSaveKey);
    }
    await _prefs!.setStringList(_ownedSkinsKey, data.ownedSkinIds);
    await _prefs!.setString(_equippedSkinKey, data.equippedSkinId);

    for (var w = 0; w < CampaignCatalog.worldCount; w++) {
      await _prefs!.remove('$_worldRewardPrefix$w');
    }
    for (final w in data.worldRewardsClaimed) {
      await _prefs!.setBool('$_worldRewardPrefix$w', true);
    }

    final keys = _prefs!.getKeys().where((k) => k.startsWith(_levelBestPrefix));
    for (final k in keys) {
      await _prefs!.remove(k);
    }
    for (final entry in data.levelBests.entries) {
      await _prefs!.setInt('$_levelBestPrefix${entry.key}', entry.value);
    }
  }

  /// Wipes all local progress (used for fresh Guest sessions).
  /// Does not touch auth session keys (`tap_dodge_auth_*`).
  Future<void> clearAllProgress() async {
    await init();
    final keys = _prefs!.getKeys().where((k) {
      if (k.startsWith('tap_dodge_auth_')) return false;
      return k.startsWith('tap_dodge_') ||
          k == _legacyUnlockedKey ||
          k == _legacyCompletedKey;
    });
    for (final k in keys.toList()) {
      await _prefs!.remove(k);
    }
    await _prefs!.setInt(_unlockedLevelKey, 1);
    await _prefs!.setInt(_completedLevelKey, 0);
    await _prefs!.setInt(_totalCoinsKey, 0);
    await _prefs!.setInt(_bestScoreKey, 0);
    await _prefs!.setStringList(_ownedSkinsKey, [ShipSkinCatalog.defaultId]);
    await _prefs!.setString(_equippedSkinKey, ShipSkinCatalog.defaultId);
  }
}
