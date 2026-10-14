/// Pure rules for whether a section/level may be cleared.
///
/// Levels must not complete from idle survival alone — the player has to
/// survive the wave, collect the section coin quota, and actually move.
class SectionObjectives {
  const SectionObjectives._();

  static bool isComplete({
    required double survivedSeconds,
    required double durationSeconds,
    required int coinsCollected,
    required int requiredCoins,
    required double travelDistance,
    required double minTravelDistance,
  }) {
    if (survivedSeconds < durationSeconds) return false;
    if (coinsCollected < requiredCoins) return false;
    if (travelDistance < minTravelDistance) return false;
    return true;
  }

  /// Combined 0..1 progress across survival, coins, and movement.
  static double progress({
    required double survivedSeconds,
    required double durationSeconds,
    required int coinsCollected,
    required int requiredCoins,
    required double travelDistance,
    required double minTravelDistance,
  }) {
    final survive = durationSeconds <= 0
        ? 1.0
        : (survivedSeconds / durationSeconds).clamp(0.0, 1.0);
    final coins = requiredCoins <= 0
        ? 1.0
        : (coinsCollected / requiredCoins).clamp(0.0, 1.0);
    final move = minTravelDistance <= 0
        ? 1.0
        : (travelDistance / minTravelDistance).clamp(0.0, 1.0);
    return (survive + coins + move) / 3.0;
  }

  /// Coin quota for a campaign section (always at least 1).
  static int requiredCoinsFor({
    required int levelNumber,
    required int sectionIndex,
  }) {
    final base = 2 + sectionIndex + (levelNumber ~/ 4);
    if (levelNumber <= 10) {
      return (base + 1).clamp(2, 8);
    }
    if (levelNumber <= 30) {
      return (base + 2).clamp(3, 10);
    }
    return (base + 3).clamp(4, 12);
  }

  /// Minimum drag/travel distance before a section can clear.
  static double minTravelFor({required int levelNumber}) {
    if (levelNumber <= 5) return 140;
    if (levelNumber <= 15) return 180;
    if (levelNumber <= 30) return 220;
    return 260;
  }
}
