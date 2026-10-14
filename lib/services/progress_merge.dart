import 'player_progress.dart';

/// Deterministic conflict resolution for guest ↔ cloud saves.
///
/// Policy (documented):
/// - Campaign unlock / completed level → take the higher value
/// - Level best scores → max per level
/// - Coins → max (never sum — avoids duplicate reward farming)
/// - World rewards / skins → set union
/// - Equipped skin → prefer [local] if owned in the merge, else cloud
/// - Streak → max
/// - Daily claim / double / streak-save day keys → lexicographically later day
/// - campaignComplete → OR
class ProgressMerge {
  const ProgressMerge._();

  static PlayerProgress merge(PlayerProgress local, PlayerProgress? cloud) {
    if (cloud == null) {
      return local.copyWith(
        schemaVersion: PlayerProgress.currentSchemaVersion,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final levelBests = <String, int>{...cloud.levelBests};
    local.levelBests.forEach((k, v) {
      final existing = levelBests[k] ?? 0;
      if (v > existing) levelBests[k] = v;
    });

    final skins = <String>{
      ...cloud.ownedSkinIds,
      ...local.ownedSkinIds,
    }.toList();
    if (!skins.contains('neon_cyan')) skins.insert(0, 'neon_cyan');

    final worlds = <int>{
      ...cloud.worldRewardsClaimed,
      ...local.worldRewardsClaimed,
    }.toList()..sort();

    final equipped = skins.contains(local.equippedSkinId)
        ? local.equippedSkinId
        : (skins.contains(cloud.equippedSkinId)
              ? cloud.equippedSkinId
              : 'neon_cyan');

    return PlayerProgress(
      schemaVersion: PlayerProgress.currentSchemaVersion,
      bestScore: _max(local.bestScore, cloud.bestScore),
      totalCoins: _max(local.totalCoins, cloud.totalCoins),
      unlockedLevel: _max(local.unlockedLevel, cloud.unlockedLevel),
      highestCompletedLevel: _max(
        local.highestCompletedLevel,
        cloud.highestCompletedLevel,
      ),
      campaignComplete: local.campaignComplete || cloud.campaignComplete,
      streak: _max(local.streak, cloud.streak),
      lastDailyClaimDay: _laterDay(
        local.lastDailyClaimDay,
        cloud.lastDailyClaimDay,
      ),
      dailyDoubleDay: _laterDay(local.dailyDoubleDay, cloud.dailyDoubleDay),
      streakSaveDay: _laterDay(local.streakSaveDay, cloud.streakSaveDay),
      ownedSkinIds: skins,
      equippedSkinId: equipped,
      worldRewardsClaimed: worlds,
      levelBests: levelBests,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static int _max(int a, int b) => a > b ? a : b;

  static String? _laterDay(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) >= 0 ? a : b;
  }
}
