import 'package:flutter/material.dart';

import '../levels/level_config.dart';

/// Campaign worlds (10 levels each).
enum CampaignWorld {
  neonTraining,
  cyberCity,
  toxicReactor,
  cosmicRift,
  finalFrontier,
}

/// Extra gameplay flavor layered on top of hazard styles.
enum SectionMechanic {
  none,
  denseCoins,
  laneSweep,
  toxicBand,
  riftPulse,
  finaleStorm,
}

class WorldTheme {
  const WorldTheme({
    required this.world,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.bgTop,
    required this.bgMid,
    required this.bgBottom,
  });

  final CampaignWorld world;
  final String name;
  final String tagline;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color bgTop;
  final Color bgMid;
  final Color bgBottom;

  int get index => world.index;

  /// Levels are 1-based inclusive.
  int get firstLevel => index * 10 + 1;
  int get lastLevel => (index + 1) * 10;
}

/// One stage inside a campaign level.
class SectionConfig {
  const SectionConfig({
    required this.index,
    required this.name,
    required this.blurb,
    required this.durationSeconds,
    required this.obstacleInterval,
    required this.fallSpeed,
    required this.maxHazards,
    required this.coinInterval,
    required this.maxCoins,
    required this.requiredCoins,
    required this.minTravelDistance,
    required this.hazardStyle,
    required this.mechanic,
    required this.sectionBonusCoins,
  });

  final int index;
  final String name;
  final String blurb;
  final double durationSeconds;
  final double obstacleInterval;
  final double fallSpeed;
  final int maxHazards;
  final double coinInterval;
  final int maxCoins;

  /// Coins the player must collect this section (skill objective).
  final int requiredCoins;

  /// Minimum drag/keyboard travel before the section can clear.
  final double minTravelDistance;

  final HazardStyle hazardStyle;
  final SectionMechanic mechanic;
  final int sectionBonusCoins;
}

/// One of the 50 main campaign levels.
class CampaignLevel {
  const CampaignLevel({
    required this.number,
    required this.name,
    required this.world,
    required this.sections,
    required this.completionCoinReward,
    required this.completionScoreReward,
  });

  final int number;
  final String name;
  final CampaignWorld world;
  final List<SectionConfig> sections;
  final int completionCoinReward;
  final int completionScoreReward;

  int get sectionCount => sections.length;

  int get totalRequiredCoins =>
      sections.fold<int>(0, (sum, s) => sum + s.requiredCoins);

  String get objectiveText {
    final seconds = sections
        .fold<double>(0, (s, e) => s + e.durationSeconds)
        .round();
    return 'Survive $seconds·s · Collect $totalRequiredCoins coins · Dodge hazards';
  }
}
