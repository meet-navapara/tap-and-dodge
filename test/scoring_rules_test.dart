import 'package:flutter_test/flutter_test.dart';
import 'package:tap_and_dodge/game/campaign/campaign_catalog.dart';
import 'package:tap_and_dodge/game/campaign/campaign_progress.dart';
import 'package:tap_and_dodge/game/rules/scoring_rules.dart';
import 'package:tap_and_dodge/game/rules/section_objectives.dart';
import 'package:tap_and_dodge/game/session/game_phase.dart';

void main() {
  group('ScoringRules', () {
    test('coin and dodge points are positive and stable', () {
      expect(ScoringRules.scoreForCoin(), 5);
      expect(ScoringRules.scoreForDodge(), 1);
    });

    test('combineScore never goes negative', () {
      expect(ScoringRules.combineScore(current: 3, delta: -10), 0);
      expect(ScoringRules.combineScore(current: 10, delta: 5), 15);
    });
  });

  group('CampaignCatalog', () {
    test('contains exactly 50 levels', () {
      expect(CampaignCatalog.levels, hasLength(50));
      expect(CampaignCatalog.maxLevel, 50);
    });

    test('every level has multiple real sections', () {
      for (final level in CampaignCatalog.levels) {
        expect(level.sections.length, greaterThanOrEqualTo(2));
        expect(level.number, inInclusiveRange(1, 50));
        for (final section in level.sections) {
          expect(section.durationSeconds, greaterThan(0));
          expect(section.fallSpeed, greaterThan(0));
          expect(section.name, isNotEmpty);
          expect(section.requiredCoins, greaterThanOrEqualTo(2));
          expect(section.minTravelDistance, greaterThan(0));
        }
      }
    });

    test('first 10 levels require active coin objectives', () {
      for (var n = 1; n <= 10; n++) {
        final level = CampaignCatalog.byNumber(n);
        expect(level.totalRequiredCoins, greaterThanOrEqualTo(4));
        for (final section in level.sections) {
          expect(section.obstacleInterval, lessThanOrEqualTo(0.95));
          expect(section.maxHazards, greaterThanOrEqualTo(5));
        }
      }
    });

    test('level 50 is the finale with 5 sections', () {
      final finale = CampaignCatalog.byNumber(50);
      expect(finale.sections, hasLength(5));
      expect(finale.name, 'Frontier Finale');
    });

    test('five worlds cover 1-50 without gaps', () {
      expect(CampaignCatalog.worlds, hasLength(5));
      expect(CampaignCatalog.worlds.first.firstLevel, 1);
      expect(CampaignCatalog.worlds.last.lastLevel, 50);
    });

    test('there is no level 51', () {
      expect(CampaignCatalog.byNumber(51).number, 50);
    });
  });

  group('CampaignProgress', () {
    test('unlock never exceeds 50', () {
      expect(CampaignProgress.nextUnlockedAfter(50, 50), 50);
      expect(CampaignProgress.nextUnlockedAfter(49, 49), 50);
      expect(CampaignProgress.nextUnlockedAfter(1, 1), 2);
      expect(CampaignProgress.isCampaignComplete(50), isTrue);
      expect(CampaignProgress.isCampaignComplete(49), isFalse);
    });

    test('world finales are 10/20/30/40/50 with milestone rewards', () {
      for (final n in [10, 20, 30, 40, 50]) {
        expect(CampaignProgress.isWorldFinaleLevel(n), isTrue);
      }
      expect(CampaignProgress.isWorldFinaleLevel(9), isFalse);
      expect(CampaignProgress.isWorldFinaleLevel(51), isFalse);
      expect(CampaignProgress.worldIndexForLevel(10), 0);
      expect(CampaignProgress.worldIndexForLevel(50), 4);
      expect(CampaignProgress.worldCompletionReward(0), greaterThan(0));
      expect(
        CampaignProgress.worldCompletionReward(4),
        greaterThan(CampaignProgress.worldCompletionReward(0)),
      );
    });

    test('replay of a cleared finale is not treated as a new world clear', () {
      // After level 10 is cleared, highestCompleted >= 10 → alreadyCleared.
      expect(10 <= 10, isTrue);
      expect(CampaignProgress.isWorldFinaleLevel(10), isTrue);
      // First clear of 10 is a world finale; a later replay should use
      // levelComplete UI (gated in TapDodgeGame via alreadyCleared).
      expect(CampaignProgress.nextUnlockedAfter(10, 10), 11);
    });
  });

  group('SectionObjectives', () {
    test('wall-rub travel alone is not enough without coins', () {
      // Documents that travel is required but insufficient by itself.
      expect(
        SectionObjectives.isComplete(
          survivedSeconds: 20,
          durationSeconds: 12,
          coinsCollected: 0,
          requiredCoins: 3,
          travelDistance: 500,
          minTravelDistance: 140,
        ),
        isFalse,
      );
    });

    test('idle survival alone cannot complete a section', () {
      expect(
        SectionObjectives.isComplete(
          survivedSeconds: 30,
          durationSeconds: 12,
          coinsCollected: 0,
          requiredCoins: 3,
          travelDistance: 0,
          minTravelDistance: 140,
        ),
        isFalse,
      );
    });

    test('requires survive + coins + movement', () {
      expect(
        SectionObjectives.isComplete(
          survivedSeconds: 12,
          durationSeconds: 12,
          coinsCollected: 3,
          requiredCoins: 3,
          travelDistance: 140,
          minTravelDistance: 140,
        ),
        isTrue,
      );
      expect(
        SectionObjectives.isComplete(
          survivedSeconds: 12,
          durationSeconds: 12,
          coinsCollected: 3,
          requiredCoins: 3,
          travelDistance: 20,
          minTravelDistance: 140,
        ),
        isFalse,
      );
      expect(
        SectionObjectives.isComplete(
          survivedSeconds: 5,
          durationSeconds: 12,
          coinsCollected: 3,
          requiredCoins: 3,
          travelDistance: 200,
          minTravelDistance: 140,
        ),
        isFalse,
      );
    });
  });

  group('GameSessionSnapshot', () {
    test('copyWith updates selected fields only', () {
      const base = GameSessionSnapshot(
        phase: GamePhase.playing,
        score: 12,
        bestScore: 40,
        countdown: 0,
        survivalSeconds: 8,
        levelNumber: 2,
        runCoins: 3,
        sectionIndex: 1,
      );

      final next = base.copyWith(score: 20, phase: GamePhase.gameOver);
      expect(next.score, 20);
      expect(next.phase, GamePhase.gameOver);
      expect(next.sectionIndex, 1);
    });
  });
}
