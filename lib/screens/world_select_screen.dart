import 'package:flutter/material.dart';

import '../game/campaign/campaign_catalog.dart';
import '../game/campaign/campaign_models.dart';
import '../game/campaign/campaign_progress.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/connectivity_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';
import 'level_select_screen.dart';

class WorldSelectScreen extends StatefulWidget {
  const WorldSelectScreen({
    super.key,
    required this.scoreService,
    required this.audioService,
    required this.connectivity,
    required this.adMob,
  });

  final ScoreService scoreService;
  final AudioService audioService;
  final ConnectivityService connectivity;
  final AdMobService adMob;

  @override
  State<WorldSelectScreen> createState() => _WorldSelectScreenState();
}

class _WorldSelectScreenState extends State<WorldSelectScreen> {
  late int _unlocked;
  late int _completed;

  @override
  void initState() {
    super.initState();
    _syncProgress();
  }

  void _syncProgress() {
    _unlocked = widget.scoreService.unlockedLevel;
    _completed = widget.scoreService.highestCompletedLevel;
  }

  Future<void> _openWorld(int index) async {
    await widget.audioService.playClick();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelSelectScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
          worldIndex: index,
        ),
      ),
    );
    if (!mounted) return;
    setState(_syncProgress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101B45), AppColors.deepNavy, AppColors.midnight],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'CAMPAIGN',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      '$_completed/${CampaignCatalog.maxLevel}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _completed / CampaignCatalog.maxLevel,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: AppColors.player,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Worlds unlocked by clearing prior worlds',
                  style: TextStyle(
                    color: AppColors.softWhite.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: CampaignCatalog.worlds.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final world = CampaignCatalog.worlds[index];
                      final isUnlocked = CampaignProgress.isWorldUnlocked(
                        index,
                        _unlocked,
                      );
                      final done = CampaignProgress.completedInWorld(
                        index,
                        _completed,
                      );
                      return _WorldCard(
                        theme: world,
                        unlocked: isUnlocked,
                        completedCount: done,
                        onTap: isUnlocked ? () => _openWorld(index) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.theme,
    required this.unlocked,
    required this.completedCount,
    required this.onTap,
  });

  final WorldTheme theme;
  final bool unlocked;
  final int completedCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                theme.bgMid.withValues(alpha: unlocked ? 0.95 : 0.45),
                theme.bgBottom.withValues(alpha: unlocked ? 0.95 : 0.45),
              ],
            ),
            border: Border.all(
              color: unlocked
                  ? theme.primary.withValues(alpha: 0.45)
                  : Colors.white12,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  unlocked ? theme.icon : Icons.lock_rounded,
                  color: unlocked ? theme.primary : Colors.white38,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: unlocked ? AppColors.softWhite : Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unlocked
                          ? theme.tagline
                          : 'Complete prior world to unlock',
                      style: TextStyle(
                        color: AppColors.softWhite.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Levels ${theme.firstLevel}–${theme.lastLevel} · $completedCount/10',
                      style: TextStyle(
                        color: theme.accent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: unlocked ? Colors.white70 : Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
