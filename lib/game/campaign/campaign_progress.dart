import 'campaign_catalog.dart';

/// Pure helpers for campaign unlock rules.
class CampaignProgress {
  static int sanitizeUnlocked(int value) =>
      value.clamp(1, CampaignCatalog.maxLevel).toInt();

  static int sanitizeCompleted(int value) =>
      value.clamp(0, CampaignCatalog.maxLevel).toInt();

  /// Completing [completedLevel] unlocks the next level, never past 50.
  static int nextUnlockedAfter(int completedLevel, int currentUnlocked) {
    if (completedLevel >= CampaignCatalog.maxLevel) {
      return CampaignCatalog.maxLevel;
    }
    final candidate = completedLevel + 1;
    return candidate > currentUnlocked ? candidate : currentUnlocked;
  }

  static bool isCampaignComplete(int highestCompleted) =>
      highestCompleted >= CampaignCatalog.maxLevel;

  static bool isWorldUnlocked(int worldIndex, int unlockedLevel) {
    final first = worldIndex * CampaignCatalog.levelsPerWorld + 1;
    return unlockedLevel >= first;
  }

  static int completedInWorld(int worldIndex, int highestCompleted) {
    final first = worldIndex * CampaignCatalog.levelsPerWorld + 1;
    final last = first + CampaignCatalog.levelsPerWorld - 1;
    if (highestCompleted < first) return 0;
    return (highestCompleted.clamp(first, last) - first + 1);
  }

  /// Levels 10 / 20 / 30 / 40 / 50 close a world.
  static bool isWorldFinaleLevel(int levelNumber) =>
      levelNumber > 0 &&
      levelNumber <= CampaignCatalog.maxLevel &&
      levelNumber % CampaignCatalog.levelsPerWorld == 0;

  static int worldIndexForLevel(int levelNumber) =>
      ((levelNumber.clamp(1, CampaignCatalog.maxLevel) - 1) ~/
              CampaignCatalog.levelsPerWorld)
          .clamp(0, CampaignCatalog.worldCount - 1);

  /// One-time milestone coins for clearing a world (world 0..4).
  static int worldCompletionReward(int worldIndex) =>
      30 + worldIndex.clamp(0, 4) * 20;
}
