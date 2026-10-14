/// Pure scoring helpers shared by gameplay and tests.
class ScoringRules {
  static const int coinPoints = 5;
  static const int dodgePoints = 1;

  static int scoreForCoin() => coinPoints;

  static int scoreForDodge() => dodgePoints;

  static int combineScore({required int current, required int delta}) {
    final next = current + delta;
    return next < 0 ? 0 : next;
  }
}
