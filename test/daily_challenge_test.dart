import 'package:flutter_test/flutter_test.dart';
import 'package:tap_and_dodge/game/meta/daily_challenge.dart';

void main() {
  test('dayKey formats local YYYY-MM-DD', () {
    expect(DailyChallengeLogic.dayKey(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('nextStreak continues across consecutive days', () {
    expect(
      DailyChallengeLogic.nextStreak(
        currentStreak: 3,
        lastClaimDay: '2026-03-04',
        today: '2026-03-05',
      ),
      4,
    );
  });

  test('nextStreak resets after a gap larger than one day', () {
    expect(
      DailyChallengeLogic.nextStreak(
        currentStreak: 5,
        lastClaimDay: '2026-03-01',
        today: '2026-03-05',
      ),
      1,
    );
  });

  test('canSaveStreak only when exactly one day was missed', () {
    expect(
      DailyChallengeLogic.canSaveStreak(
        currentStreak: 4,
        lastClaimDay: '2026-03-03',
        today: '2026-03-05',
        alreadySavedToday: false,
      ),
      isTrue,
    );
    expect(
      DailyChallengeLogic.canSaveStreak(
        currentStreak: 4,
        lastClaimDay: '2026-03-04',
        today: '2026-03-05',
        alreadySavedToday: false,
      ),
      isFalse,
    );
  });

  test('challengeLevelForDay stays within unlocked range', () {
    final level = DailyChallengeLogic.challengeLevelForDay('2026-10-13', 12);
    expect(level, inInclusiveRange(1, 12));
  });

  test('calendar yesterday helper via DateTime day-1 is stable', () {
    final now = DateTime(2026, 3, 1);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    expect(DailyChallengeLogic.dayKey(yesterday), '2026-02-28');
  });
}
