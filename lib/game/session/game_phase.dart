/// High-level round phases for the 50-level campaign.
enum GamePhase {
  loading,
  ready,
  levelIntro,
  sectionIntro,
  countdown,
  playing,
  paused,
  sectionComplete,
  levelComplete,
  worldComplete,
  campaignComplete,
  gameOver,
}

/// Snapshot of a single-player round.
class GameSessionSnapshot {
  const GameSessionSnapshot({
    required this.phase,
    required this.score,
    required this.bestScore,
    required this.countdown,
    required this.survivalSeconds,
    required this.levelNumber,
    required this.runCoins,
    required this.sectionIndex,
    this.playerId = 'local-player',
    this.roomCode,
  });

  final GamePhase phase;
  final int score;
  final int bestScore;
  final int countdown;
  final double survivalSeconds;
  final int levelNumber;
  final int runCoins;
  final int sectionIndex;
  final String playerId;
  final String? roomCode;

  GameSessionSnapshot copyWith({
    GamePhase? phase,
    int? score,
    int? bestScore,
    int? countdown,
    double? survivalSeconds,
    int? levelNumber,
    int? runCoins,
    int? sectionIndex,
    String? playerId,
    String? roomCode,
  }) {
    return GameSessionSnapshot(
      phase: phase ?? this.phase,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      countdown: countdown ?? this.countdown,
      survivalSeconds: survivalSeconds ?? this.survivalSeconds,
      levelNumber: levelNumber ?? this.levelNumber,
      runCoins: runCoins ?? this.runCoins,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      playerId: playerId ?? this.playerId,
      roomCode: roomCode ?? this.roomCode,
    );
  }
}
