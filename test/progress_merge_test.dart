import 'package:flutter_test/flutter_test.dart';
import 'package:tap_and_dodge/services/player_progress.dart';
import 'package:tap_and_dodge/services/progress_merge.dart';

void main() {
  test('merge takes max unlock and coins (never sums coins)', () {
    final local = PlayerProgress.empty().copyWith(
      unlockedLevel: 12,
      totalCoins: 100,
      highestCompletedLevel: 11,
      levelBests: {'1': 40, '2': 10},
    );
    final cloud = PlayerProgress.empty().copyWith(
      unlockedLevel: 8,
      totalCoins: 250,
      highestCompletedLevel: 7,
      levelBests: {'1': 20, '3': 90},
    );

    final merged = ProgressMerge.merge(local, cloud);
    expect(merged.unlockedLevel, 12);
    expect(merged.totalCoins, 250);
    expect(merged.highestCompletedLevel, 11);
    expect(merged.levelBests['1'], 40);
    expect(merged.levelBests['2'], 10);
    expect(merged.levelBests['3'], 90);
  });

  test('merge unions skins and world rewards', () {
    final local = PlayerProgress.empty().copyWith(
      ownedSkinIds: ['neon_cyan', 'vio_pulse'],
      worldRewardsClaimed: [0],
      equippedSkinId: 'vio_pulse',
    );
    final cloud = PlayerProgress.empty().copyWith(
      ownedSkinIds: ['neon_cyan', 'ember'],
      worldRewardsClaimed: [1],
      equippedSkinId: 'ember',
    );

    final merged = ProgressMerge.merge(local, cloud);
    expect(
      merged.ownedSkinIds,
      containsAll(['neon_cyan', 'vio_pulse', 'ember']),
    );
    expect(merged.worldRewardsClaimed, containsAll([0, 1]));
    expect(merged.equippedSkinId, 'vio_pulse');
  });

  test('merge with null cloud returns local with schema', () {
    final local = PlayerProgress.empty().copyWith(unlockedLevel: 5);
    final merged = ProgressMerge.merge(local, null);
    expect(merged.unlockedLevel, 5);
    expect(merged.schemaVersion, PlayerProgress.currentSchemaVersion);
  });
}
