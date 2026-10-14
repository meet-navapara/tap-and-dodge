import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/campaign/campaign_catalog.dart';
import '../game/campaign/campaign_models.dart';
import '../game/campaign/campaign_progress.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/connectivity_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';
import '../widgets/level_card.dart';
import 'connection_required_screen.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({
    super.key,
    required this.scoreService,
    required this.audioService,
    required this.connectivity,
    required this.adMob,
    required this.worldIndex,
  });

  final ScoreService scoreService;
  final AudioService audioService;
  final ConnectivityService connectivity;
  final AdMobService adMob;
  final int worldIndex;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  late int _unlocked;
  late int _completed;
  int? _launchingLevel;

  WorldTheme get _world => CampaignCatalog.worldThemeAt(widget.worldIndex);

  @override
  void initState() {
    super.initState();
    _syncProgress();
  }

  void _syncProgress() {
    _unlocked = widget.scoreService.unlockedLevel;
    _completed = widget.scoreService.highestCompletedLevel;
  }

  LevelCardState _stateFor(int levelNumber) {
    if (levelNumber > _unlocked) return LevelCardState.locked;
    if (levelNumber <= _completed) return LevelCardState.completed;
    if (levelNumber == _unlocked) return LevelCardState.current;
    return LevelCardState.available;
  }

  /// Next recommended level inside this world, if any.
  int? get _recommendedLevel {
    final first = _world.firstLevel;
    final last = _world.lastLevel;
    if (_unlocked < first) return null;
    final candidate = _unlocked.clamp(first, last);
    if (candidate <= _completed && candidate == last) {
      // World fully cleared — nudge replay of final world level.
      return last;
    }
    if (candidate <= _completed) return null;
    return candidate;
  }

  int get _worldCompleted =>
      CampaignProgress.completedInWorld(widget.worldIndex, _completed);

  Future<void> _openLevel(int levelNumber) async {
    if (levelNumber > _unlocked || _launchingLevel != null) return;

    var online = await widget.connectivity.refresh(forceProbe: true);
    if (!mounted) return;
    if (!online) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConnectionRequiredScreen(
            onRetry: () async {
              final ok = await widget.connectivity.refresh(forceProbe: true);
              if (ok && mounted) Navigator.of(context).pop();
            },
          ),
        ),
      );
      if (!mounted) return;
      // B07: continue into the level after a successful Retry.
      online = await widget.connectivity.refresh(forceProbe: true);
      if (!online) return;
    }

    setState(() => _launchingLevel = levelNumber);
    await widget.audioService.playClick();
    HapticFeedback.lightImpact();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
          initialLevel: levelNumber,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _syncProgress();
      _launchingLevel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final world = _world;
    final recommended = _recommendedLevel;
    final campaignDone = widget.scoreService.highestCompletedLevel;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 720;
    final columns = wide ? 3 : 2;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [world.bgTop, world.bgMid, world.bgBottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: _GlowOrb(color: world.primary, size: 220, opacity: 0.16),
            ),
            Positioned(
              bottom: 40,
              left: -70,
              child: _GlowOrb(color: world.secondary, size: 180, opacity: 0.12),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: _LevelSelectHeader(
                              world: world,
                              worldCompleted: _worldCompleted,
                              campaignCompleted: campaignDone,
                              onBack: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        if (recommended != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                              child: _FeaturedLevelCard(
                                level: CampaignCatalog.byNumber(recommended),
                                world: world,
                                bestScore: widget.scoreService
                                    .bestScoreForLevel(recommended),
                                completed: recommended <= _completed,
                                busy: _launchingLevel == recommended,
                                onPlay: () => _openLevel(recommended),
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                            child: Row(
                              children: [
                                Text(
                                  'WORLD LEVELS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                    color: world.primary.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$_worldCompleted/10',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: world.accent.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.crossAxisExtent;
                              final spacing = 12.0;
                              final cardWidth =
                                  (width - spacing * (columns - 1)) / columns;
                              final aspect = cardWidth < 160 ? 0.86 : 0.92;

                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: spacing,
                                      crossAxisSpacing: spacing,
                                      childAspectRatio: aspect,
                                    ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  i,
                                ) {
                                  final levelNumber = world.firstLevel + i;
                                  final level = CampaignCatalog.byNumber(
                                    levelNumber,
                                  );
                                  final state = _stateFor(levelNumber);
                                  return LevelCard(
                                    number: levelNumber,
                                    name: level.name,
                                    state: state,
                                    primary: world.primary,
                                    secondary: world.secondary,
                                    accent: world.accent,
                                    bestScore: widget.scoreService
                                        .bestScoreForLevel(levelNumber),
                                    onTap: state == LevelCardState.locked
                                        ? null
                                        : () => _openLevel(levelNumber),
                                  );
                                }, childCount: CampaignCatalog.levelsPerWorld),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recommended != null)
                    _BottomPlayBar(
                      world: world,
                      levelNumber: recommended,
                      levelName: CampaignCatalog.byNumber(recommended).name,
                      busy: _launchingLevel == recommended,
                      onPlay: () => _openLevel(recommended),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelSelectHeader extends StatelessWidget {
  const _LevelSelectHeader({
    required this.world,
    required this.worldCompleted,
    required this.campaignCompleted,
    required this.onBack,
  });

  final WorldTheme world;
  final int worldCompleted;
  final int campaignCompleted;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final progress = worldCompleted / CampaignCatalog.levelsPerWorld;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'SELECT LEVEL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: AppColors.softWhite.withValues(alpha: 0.55),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                '$campaignCompleted/${CampaignCatalog.maxLevel}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                world.primary.withValues(alpha: 0.18),
                world.bgMid.withValues(alpha: 0.9),
                Colors.black.withValues(alpha: 0.35),
              ],
            ),
            border: Border.all(color: world.primary.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: world.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      world.primary.withValues(alpha: 0.35),
                      world.secondary.withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border.all(
                    color: world.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(world.icon, color: world.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      world.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      world.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: AppColors.softWhite.withValues(alpha: 0.62),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              color: world.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$worldCompleted/10',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: world.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Levels ${world.firstLevel}–${world.lastLevel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.softWhite.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedLevelCard extends StatelessWidget {
  const _FeaturedLevelCard({
    required this.level,
    required this.world,
    required this.bestScore,
    required this.completed,
    required this.busy,
    required this.onPlay,
  });

  final CampaignLevel level;
  final WorldTheme world;
  final int bestScore;
  final bool completed;
  final bool busy;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onPlay,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                world.accent.withValues(alpha: 0.28),
                world.primary.withValues(alpha: 0.18),
                const Color(0xFF0C1428).withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: world.accent.withValues(alpha: 0.7),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: world.accent.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      world.accent.withValues(alpha: 0.35),
                      world.primary.withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border.all(
                    color: world.accent.withValues(alpha: 0.55),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${level.number}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: world.accent.withValues(alpha: 0.6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      completed ? 'REPLAY FEATURED' : 'CONTINUE HERE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: world.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.objectiveText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.softWhite.withValues(alpha: 0.55),
                      ),
                    ),
                    if (bestScore > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Best score $bestScore',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: world.accent.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: world.accent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: world.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF101528),
                        ),
                      )
                    : const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF101528),
                        size: 30,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPlayBar extends StatelessWidget {
  const _BottomPlayBar({
    required this.world,
    required this.levelNumber,
    required this.levelName,
    required this.busy,
    required this.onPlay,
  });

  final WorldTheme world;
  final int levelNumber;
  final String levelName;
  final bool busy;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            world.bgBottom.withValues(alpha: 0),
            world.bgBottom.withValues(alpha: 0.92),
            world.bgBottom,
          ],
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: busy ? null : onPlay,
            style: ElevatedButton.styleFrom(
              backgroundColor: world.accent,
              foregroundColor: const Color(0xFF101528),
              disabledBackgroundColor: world.accent.withValues(alpha: 0.45),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(
                    'PLAY LEVEL $levelNumber · ${levelName.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
