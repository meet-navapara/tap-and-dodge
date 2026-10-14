import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_and_dodge/services/score_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ScoreService banks coins and unlocks up to 50 only', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ScoreService();
    await service.init();

    expect(service.unlockedLevel, 1);
    final firstGrant = await service.completeLevel(1, coinReward: 5, score: 40);
    expect(firstGrant, 5);
    expect(service.unlockedLevel, 2);
    expect(service.highestCompletedLevel, 1);
    expect(service.bestScoreForLevel(1), 40);
    expect(service.totalCoins, 5);

    await service.completeLevel(49, coinReward: 10, score: 100);
    expect(service.unlockedLevel, 50);

    await service.completeLevel(50, coinReward: 30, score: 200);
    expect(service.unlockedLevel, 50);
    expect(service.isCampaignComplete, isTrue);
  });

  test('ScoreService does not re-grant completion coins on replay', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ScoreService();
    await service.init();

    await service.completeLevel(1, coinReward: 8, score: 50);
    expect(service.totalCoins, 8);

    final replayGrant = await service.completeLevel(
      1,
      coinReward: 8,
      score: 80,
    );
    expect(replayGrant, 0);
    expect(service.totalCoins, 8);
    expect(service.unlockedLevel, 2);
    expect(service.bestScoreForLevel(1), 80);
  });

  test('ScoreService world rewards are one-time only', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ScoreService();
    await service.init();

    final first = await service.grantWorldReward(0, coinReward: 30);
    expect(first, 30);
    expect(service.totalCoins, 30);
    expect(service.isWorldRewardClaimed(0), isTrue);

    final again = await service.grantWorldReward(0, coinReward: 30);
    expect(again, 0);
    expect(service.totalCoins, 30);
  });

  test('ScoreService daily claim and double are once per day', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ScoreService();
    await service.init();

    final first = await service.claimDailyReward();
    expect(first, greaterThan(0));
    expect(service.hasClaimedDailyToday, isTrue);
    expect(service.streak, 1);
    expect(await service.claimDailyReward(), 0);

    final doubled = await service.claimDailyDoubleReward();
    expect(doubled, greaterThan(0));
    expect(service.hasClaimedDailyDoubleToday, isTrue);
    expect(await service.claimDailyDoubleReward(), 0);
  });

  test('ScoreService skin purchase spends coins and equips', () async {
    SharedPreferences.setMockInitialValues({'tap_dodge_total_coins': 200});
    final service = ScoreService();
    await service.init();

    expect(await service.purchaseSkin('vio_pulse'), isTrue);
    expect(service.ownsSkin('vio_pulse'), isTrue);
    expect(service.totalCoins, lessThan(200));
    await service.equipSkin('vio_pulse');
    expect(service.equippedSkinId, 'vio_pulse');
  });

  test(
    'ScoreService saveStreak refuses after already claiming today',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = ScoreService();
      await service.init();

      await service.claimDailyReward();
      expect(await service.saveStreakWithAd(), isFalse);
    },
  );

  test('clearAllProgress wipes progress but keeps auth keys', () async {
    SharedPreferences.setMockInitialValues({
      'tap_dodge_total_coins': 99,
      'tap_dodge_unlocked_level_v2': 12,
      'tap_dodge_auth_mode': 'guest',
      'tap_dodge_auth_guest': true,
    });
    final service = ScoreService();
    await service.init();
    await service.clearAllProgress();

    expect(service.totalCoins, 0);
    expect(service.unlockedLevel, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tap_dodge_auth_mode'), 'guest');
    expect(prefs.getBool('tap_dodge_auth_guest'), isTrue);
  });

  test('exportProgress / importProgress round-trips campaign data', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ScoreService();
    await service.init();
    await service.completeLevel(1, coinReward: 5, score: 40);
    await service.addCoins(20);

    final snapshot = service.exportProgress();
    await service.clearAllProgress();
    expect(service.unlockedLevel, 1);
    expect(service.totalCoins, 0);

    await service.importProgress(snapshot);
    expect(service.unlockedLevel, 2);
    expect(service.highestCompletedLevel, 1);
    expect(service.bestScoreForLevel(1), 40);
    expect(service.totalCoins, 25);
  });
}
