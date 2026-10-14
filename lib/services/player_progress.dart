/// Cloud + local progress snapshot for Tap & Dodge (50-level campaign).
class PlayerProgress {
  const PlayerProgress({
    this.schemaVersion = currentSchemaVersion,
    required this.bestScore,
    required this.totalCoins,
    required this.unlockedLevel,
    required this.highestCompletedLevel,
    required this.campaignComplete,
    required this.streak,
    this.lastDailyClaimDay,
    this.dailyDoubleDay,
    this.streakSaveDay,
    required this.ownedSkinIds,
    required this.equippedSkinId,
    required this.worldRewardsClaimed,
    required this.levelBests,
    this.updatedAtMs,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int bestScore;
  final int totalCoins;
  final int unlockedLevel;
  final int highestCompletedLevel;
  final bool campaignComplete;
  final int streak;
  final String? lastDailyClaimDay;
  final String? dailyDoubleDay;
  final String? streakSaveDay;
  final List<String> ownedSkinIds;
  final String equippedSkinId;
  final List<int> worldRewardsClaimed;
  final Map<String, int> levelBests;
  final int? updatedAtMs;

  factory PlayerProgress.empty() => const PlayerProgress(
    bestScore: 0,
    totalCoins: 0,
    unlockedLevel: 1,
    highestCompletedLevel: 0,
    campaignComplete: false,
    streak: 0,
    ownedSkinIds: ['neon_cyan'],
    equippedSkinId: 'neon_cyan',
    worldRewardsClaimed: [],
    levelBests: {},
  );

  PlayerProgress copyWith({
    int? schemaVersion,
    int? bestScore,
    int? totalCoins,
    int? unlockedLevel,
    int? highestCompletedLevel,
    bool? campaignComplete,
    int? streak,
    String? lastDailyClaimDay,
    String? dailyDoubleDay,
    String? streakSaveDay,
    List<String>? ownedSkinIds,
    String? equippedSkinId,
    List<int>? worldRewardsClaimed,
    Map<String, int>? levelBests,
    int? updatedAtMs,
  }) {
    return PlayerProgress(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      bestScore: bestScore ?? this.bestScore,
      totalCoins: totalCoins ?? this.totalCoins,
      unlockedLevel: unlockedLevel ?? this.unlockedLevel,
      highestCompletedLevel:
          highestCompletedLevel ?? this.highestCompletedLevel,
      campaignComplete: campaignComplete ?? this.campaignComplete,
      streak: streak ?? this.streak,
      lastDailyClaimDay: lastDailyClaimDay ?? this.lastDailyClaimDay,
      dailyDoubleDay: dailyDoubleDay ?? this.dailyDoubleDay,
      streakSaveDay: streakSaveDay ?? this.streakSaveDay,
      ownedSkinIds: ownedSkinIds ?? this.ownedSkinIds,
      equippedSkinId: equippedSkinId ?? this.equippedSkinId,
      worldRewardsClaimed: worldRewardsClaimed ?? this.worldRewardsClaimed,
      levelBests: levelBests ?? this.levelBests,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': schemaVersion,
    'bestScore': bestScore,
    'totalCoins': totalCoins,
    'unlockedLevel': unlockedLevel,
    'highestCompletedLevel': highestCompletedLevel,
    'campaignComplete': campaignComplete,
    'streak': streak,
    'lastDailyClaimDay': lastDailyClaimDay,
    'dailyDoubleDay': dailyDoubleDay,
    'streakSaveDay': streakSaveDay,
    'ownedSkinIds': ownedSkinIds,
    'equippedSkinId': equippedSkinId,
    'worldRewardsClaimed': worldRewardsClaimed,
    'levelBests': levelBests,
    'updatedAtMs': updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
  };

  factory PlayerProgress.fromMap(Map<String, dynamic>? data) {
    if (data == null) return PlayerProgress.empty();
    final levelBestsRaw = data['levelBests'];
    final levelBests = <String, int>{};
    if (levelBestsRaw is Map) {
      levelBestsRaw.forEach((k, v) {
        final score = v is int ? v : int.tryParse('$v') ?? 0;
        levelBests['$k'] = score;
      });
    }
    final worlds = data['worldRewardsClaimed'];
    final worldList = <int>[];
    if (worlds is List) {
      for (final w in worlds) {
        if (w is int) {
          worldList.add(w);
        } else {
          final parsed = int.tryParse('$w');
          if (parsed != null) worldList.add(parsed);
        }
      }
    }
    final skins = data['ownedSkinIds'];
    final skinList = <String>[];
    if (skins is List) {
      for (final s in skins) {
        skinList.add('$s');
      }
    }
    if (skinList.isEmpty) skinList.add('neon_cyan');

    final version = (data['schemaVersion'] as num?)?.toInt() ?? 1;

    return PlayerProgress(
      schemaVersion: version,
      bestScore: (data['bestScore'] as num?)?.toInt() ?? 0,
      totalCoins: (data['totalCoins'] as num?)?.toInt() ?? 0,
      unlockedLevel: (data['unlockedLevel'] as num?)?.toInt() ?? 1,
      highestCompletedLevel:
          (data['highestCompletedLevel'] as num?)?.toInt() ?? 0,
      campaignComplete: data['campaignComplete'] == true,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      lastDailyClaimDay: data['lastDailyClaimDay'] as String?,
      dailyDoubleDay: data['dailyDoubleDay'] as String?,
      streakSaveDay: data['streakSaveDay'] as String?,
      ownedSkinIds: skinList,
      equippedSkinId: (data['equippedSkinId'] as String?) ?? 'neon_cyan',
      worldRewardsClaimed: worldList,
      levelBests: levelBests,
      updatedAtMs: (data['updatedAtMs'] as num?)?.toInt(),
    );
  }
}
