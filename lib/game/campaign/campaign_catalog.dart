import 'package:flutter/material.dart';

import '../levels/level_config.dart';
import '../rules/section_objectives.dart';
import 'campaign_models.dart';

/// Canonical 50-level campaign definition.
class CampaignCatalog {
  static const int maxLevel = 50;
  static const int levelsPerWorld = 10;
  static const int worldCount = 5;

  static const List<WorldTheme> worlds = [
    WorldTheme(
      world: CampaignWorld.neonTraining,
      name: 'Neon Training',
      tagline: 'Learn to fly, collect, and dodge.',
      icon: Icons.school_rounded,
      primary: Color(0xFF39F3FF),
      secondary: Color(0xFF7B5CFF),
      accent: Color(0xFFFFD76A),
      bgTop: Color(0xFF0A1030),
      bgMid: Color(0xFF101B45),
      bgBottom: Color(0xFF070B1A),
    ),
    WorldTheme(
      world: CampaignWorld.cyberCity,
      name: 'Cyber City',
      tagline: 'Traffic lanes of neon danger.',
      icon: Icons.location_city_rounded,
      primary: Color(0xFF4DA3FF),
      secondary: Color(0xFF00E5A8),
      accent: Color(0xFFFFC857),
      bgTop: Color(0xFF081828),
      bgMid: Color(0xFF0D2740),
      bgBottom: Color(0xFF040C16),
    ),
    WorldTheme(
      world: CampaignWorld.toxicReactor,
      name: 'Toxic Reactor',
      tagline: 'Survive acid bands and unstable cores.',
      icon: Icons.science_rounded,
      primary: Color(0xFFB8FF3D),
      secondary: Color(0xFFFF5C7A),
      accent: Color(0xFFE8FF7A),
      bgTop: Color(0xFF101808),
      bgMid: Color(0xFF1C2A0E),
      bgBottom: Color(0xFF070A04),
    ),
    WorldTheme(
      world: CampaignWorld.cosmicRift,
      name: 'Cosmic Rift',
      tagline: 'Gravity twists and starfire hazards.',
      icon: Icons.auto_awesome_rounded,
      primary: Color(0xFFC084FC),
      secondary: Color(0xFF60A5FA),
      accent: Color(0xFFF0ABFC),
      bgTop: Color(0xFF14081F),
      bgMid: Color(0xFF1E1038),
      bgBottom: Color(0xFF080412),
    ),
    WorldTheme(
      world: CampaignWorld.finalFrontier,
      name: 'Final Frontier',
      tagline: 'The campaign\'s ultimate gauntlet.',
      icon: Icons.rocket_launch_rounded,
      primary: Color(0xFFFF6B6B),
      secondary: Color(0xFFFFD93D),
      accent: Color(0xFF6BCBFF),
      bgTop: Color(0xFF1A0A12),
      bgMid: Color(0xFF2A1020),
      bgBottom: Color(0xFF0A0408),
    ),
  ];

  static final List<CampaignLevel> levels = List.generate(
    maxLevel,
    (i) => _buildLevel(i + 1),
  );

  static WorldTheme themeForWorld(CampaignWorld world) => worlds[world.index];

  static WorldTheme themeForLevel(int levelNumber) =>
      themeForWorld(worldForLevel(levelNumber));

  static CampaignWorld worldForLevel(int levelNumber) {
    final n = levelNumber.clamp(1, maxLevel);
    return CampaignWorld.values[(n - 1) ~/ levelsPerWorld];
  }

  static CampaignLevel byNumber(int number) {
    final n = number.clamp(1, maxLevel);
    return levels[n - 1];
  }

  static WorldTheme worldThemeAt(int worldIndex) =>
      worlds[worldIndex.clamp(0, worldCount - 1)];

  static CampaignLevel _buildLevel(int number) {
    final world = worldForLevel(number);
    final localIndex = ((number - 1) % levelsPerWorld) + 1; // 1..10
    final sectionCount = _sectionCountFor(number);
    final sections = List.generate(
      sectionCount,
      (i) => _buildSection(
        levelNumber: number,
        world: world,
        sectionIndex: i,
        sectionCount: sectionCount,
        localIndex: localIndex,
      ),
    );

    return CampaignLevel(
      number: number,
      name: _levelName(world, localIndex),
      world: world,
      sections: sections,
      completionCoinReward: 8 + (number ~/ 2) + (localIndex == 10 ? 20 : 0),
      completionScoreReward: 15 + number + (localIndex == 10 ? 40 : 0),
    );
  }

  static int _sectionCountFor(int number) {
    if (number <= 5) return 2;
    if (number <= 15) return 3;
    if (number <= 30) return 3;
    if (number <= 40) return 4;
    if (number < 50) return 4;
    return 5; // Level 50 finale
  }

  static SectionConfig _buildSection({
    required int levelNumber,
    required CampaignWorld world,
    required int sectionIndex,
    required int sectionCount,
    required int localIndex,
  }) {
    final t = (levelNumber - 1) / (maxLevel - 1); // 0..1
    final sectionBoost = sectionCount <= 1
        ? 0.0
        : sectionIndex / (sectionCount - 1);

    // Early levels are intentionally denser so AFK / idle clears are impossible.
    final earlyPush = levelNumber <= 10 ? 1.0 : 0.0;
    final baseFall = 185 + t * 195 + sectionBoost * 40 + earlyPush * 25;
    final baseInterval =
        0.88 - t * 0.42 - sectionBoost * 0.1 - earlyPush * 0.12;
    final baseCoins = 1.35 - t * 0.55 - sectionBoost * 0.08 - earlyPush * 0.15;

    final mechanic = _mechanicFor(
      world,
      sectionIndex,
      levelNumber,
      sectionCount,
    );
    final hazard = _hazardFor(world, sectionIndex, levelNumber);
    final requiredCoins = SectionObjectives.requiredCoinsFor(
      levelNumber: levelNumber,
      sectionIndex: sectionIndex,
    );

    final duration =
        14.0 +
        localIndex * 0.55 +
        sectionIndex * 2.0 +
        (levelNumber >= 40 ? 2.0 : 0) +
        (levelNumber == 50 ? 3.0 : 0);

    return SectionConfig(
      index: sectionIndex,
      name: _sectionName(world, sectionIndex, sectionCount, levelNumber),
      blurb: _sectionBlurb(mechanic, world),
      durationSeconds: duration.clamp(12, 34),
      obstacleInterval: baseInterval.clamp(0.34, 0.95),
      fallSpeed: baseFall.clamp(180, 420),
      maxHazards: (5 + (t * 5).round() + sectionIndex + (earlyPush > 0 ? 1 : 0))
          .clamp(5, 12),
      coinInterval: baseCoins.clamp(0.45, 1.35),
      maxCoins:
          (4 +
                  (t * 2).round() +
                  (mechanic == SectionMechanic.denseCoins ? 2 : 0))
              .clamp(4, 9),
      requiredCoins: requiredCoins,
      minTravelDistance: SectionObjectives.minTravelFor(
        levelNumber: levelNumber,
      ),
      hazardStyle: hazard,
      mechanic: mechanic,
      sectionBonusCoins: 2 + sectionIndex + (levelNumber ~/ 10),
    );
  }

  static HazardStyle _hazardFor(
    CampaignWorld world,
    int sectionIndex,
    int levelNumber,
  ) {
    if (levelNumber <= 5) return HazardStyle.standard;
    if (world == CampaignWorld.neonTraining) {
      return sectionIndex == 0 ? HazardStyle.standard : HazardStyle.drifter;
    }
    if (world == CampaignWorld.cyberCity) {
      return sectionIndex.isEven ? HazardStyle.drifter : HazardStyle.spinner;
    }
    if (sectionIndex == 0) return HazardStyle.drifter;
    if (sectionIndex == 1) return HazardStyle.spinner;
    return sectionIndex.isEven ? HazardStyle.drifter : HazardStyle.spinner;
  }

  static SectionMechanic _mechanicFor(
    CampaignWorld world,
    int sectionIndex,
    int levelNumber,
    int sectionCount,
  ) {
    if (levelNumber == 50) {
      return [
        SectionMechanic.denseCoins,
        SectionMechanic.laneSweep,
        SectionMechanic.riftPulse,
        SectionMechanic.toxicBand,
        SectionMechanic.finaleStorm,
      ][sectionIndex.clamp(0, 4)];
    }
    if (levelNumber <= 5) return SectionMechanic.none;
    if (levelNumber <= 10) {
      // Neon Storm (10) finale previews poison so players see it before World 3.
      if (levelNumber == 10 && sectionIndex >= sectionCount - 1) {
        return SectionMechanic.toxicBand;
      }
      return sectionIndex >= 1
          ? SectionMechanic.denseCoins
          : SectionMechanic.none;
    }
    switch (world) {
      case CampaignWorld.cyberCity:
        return sectionIndex == 0
            ? SectionMechanic.none
            : (sectionIndex == 1
                  ? SectionMechanic.laneSweep
                  : SectionMechanic.denseCoins);
      case CampaignWorld.toxicReactor:
        return sectionIndex >= 1
            ? SectionMechanic.toxicBand
            : SectionMechanic.laneSweep;
      case CampaignWorld.cosmicRift:
        return sectionIndex >= 1
            ? SectionMechanic.riftPulse
            : SectionMechanic.denseCoins;
      case CampaignWorld.finalFrontier:
        return sectionIndex >= 2
            ? SectionMechanic.finaleStorm
            : (sectionIndex == 1
                  ? SectionMechanic.toxicBand
                  : SectionMechanic.laneSweep);
      case CampaignWorld.neonTraining:
        return SectionMechanic.denseCoins;
    }
  }

  static String _levelName(CampaignWorld world, int localIndex) {
    const names = {
      CampaignWorld.neonTraining: [
        'First Flight',
        'Glow Trail',
        'Pulse Alley',
        'Soft Storm',
        'Coin Cascade',
        'Drift Lesson',
        'Neon Cross',
        'Spark Run',
        'Training Peak',
        'Neon Storm',
      ],
      CampaignWorld.cyberCity: [
        'Skyline Entry',
        'Gridlock',
        'Hover Lane',
        'Signal Jam',
        'Billboard Blitz',
        'Metro Surge',
        'Chrome Rain',
        'Overpass',
        'Night Market',
        'City Core',
      ],
      CampaignWorld.toxicReactor: [
        'Coolant Leak',
        'Acid Rim',
        'Core Alarm',
        'Vent Chase',
        'Greenlight',
        'Meltdown Mile',
        'Geiger Run',
        'Containment',
        'Reactor Row',
        'Critical Mass',
      ],
      CampaignWorld.cosmicRift: [
        'Starwake',
        'Void Slip',
        'Aurora Cut',
        'Orbit Dust',
        'Rift Echo',
        'Nebula Needle',
        'Gravity Fold',
        'Quasar Dash',
        'Event Horizon',
        'Singularity',
      ],
      CampaignWorld.finalFrontier: [
        'Breach Gate',
        'Last Beacon',
        'Iron Halo',
        'Burn Vector',
        'Echo Siege',
        'Crown Fire',
        'Apex Drift',
        'Omega Line',
        'Throne Rush',
        'Frontier Finale',
      ],
    };
    return names[world]![localIndex - 1];
  }

  static String _sectionName(
    CampaignWorld world,
    int sectionIndex,
    int sectionCount,
    int levelNumber,
  ) {
    if (levelNumber == 50) {
      return [
        'Opening Barrage',
        'Lane Collapse',
        'Rift Surge',
        'Toxic Heart',
        'Final Stand',
      ][sectionIndex];
    }
    final labels = switch (world) {
      CampaignWorld.neonTraining => ['Warmup', 'Focus', 'Challenge', 'Mastery'],
      CampaignWorld.cyberCity => [
        'Approach',
        'Traffic',
        'Rush Hour',
        'Lockdown',
      ],
      CampaignWorld.toxicReactor => ['Leak', 'Alarm', 'Unstable', 'Critical'],
      CampaignWorld.cosmicRift => ['Drift', 'Fold', 'Pulse', 'Collapse'],
      CampaignWorld.finalFrontier => ['Breach', 'Siege', 'Apex', 'Throne'],
    };
    if (sectionIndex == sectionCount - 1 && sectionCount > 1) {
      return 'Finale · ${labels[sectionIndex.clamp(0, labels.length - 1)]}';
    }
    return 'Section ${sectionIndex + 1} · ${labels[sectionIndex.clamp(0, labels.length - 1)]}';
  }

  static String _sectionBlurb(SectionMechanic mechanic, CampaignWorld world) {
    return switch (mechanic) {
      SectionMechanic.none => 'Dodge hazards and collect falling coins.',
      SectionMechanic.denseCoins => 'Coin density rises — claim the gold rain.',
      SectionMechanic.laneSweep => 'Hazards sweep sideways. Read the lanes.',
      SectionMechanic.toxicBand => 'Avoid lingering in the toxic band.',
      SectionMechanic.riftPulse => 'Rift pulses warp hazard timing.',
      SectionMechanic.finaleStorm => 'Everything converges. Stay sharp.',
    };
  }
}
