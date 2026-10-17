import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/campaign/campaign_catalog.dart';
import '../game/meta/daily_challenge.dart';
import '../game/meta/ship_skins.dart';
import '../services/ad_policies.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/progress_sync_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';
import 'connection_required_screen.dart';
import 'game_screen.dart';
import 'hangar_screen.dart';
import 'settings_screen.dart';
import 'world_select_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.scoreService,
    required this.audioService,
    required this.connectivity,
    required this.adMob,
    this.auth,
    this.sync,
  });

  final ScoreService scoreService;
  final AudioService audioService;
  final ConnectivityService connectivity;
  final AdMobService adMob;
  final AuthService? auth;
  final ProgressSyncService? sync;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _drift;
  int _bestScore = 0;
  int _totalCoins = 0;
  int _unlockedLevel = 1;
  int _completed = 0;
  int _streak = 0;
  int _challengeLevel = 1;
  bool _claimedDaily = false;
  bool _claimedDouble = false;
  bool _canSaveStreak = false;
  bool _loading = true;
  bool _dailyBusy = false;
  String? _dailyMessage;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _bootstrap();
  }

  void _syncMeta() {
    _bestScore = widget.scoreService.bestScore;
    _totalCoins = widget.scoreService.totalCoins;
    _unlockedLevel = widget.scoreService.unlockedLevel;
    _completed = widget.scoreService.highestCompletedLevel;
    _streak = widget.scoreService.streak;
    _challengeLevel = widget.scoreService.todaysChallengeLevel;
    _claimedDaily = widget.scoreService.hasClaimedDailyToday;
    _claimedDouble = widget.scoreService.hasClaimedDailyDoubleToday;
    _canSaveStreak = widget.scoreService.canSaveStreak;
  }

  Future<void> _bootstrap() async {
    await widget.scoreService.init();
    await widget.audioService.init();
    // Ensure SDK is up; preload is serialized inside AdMobService.
    unawaited(widget.adMob.ensureInitialized());
    if (!mounted) return;
    setState(() {
      _syncMeta();
      _loading = false;
    });
    await widget.audioService.startMusic();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _drift.dispose();
    super.dispose();
  }

  Future<bool> _requireOnline() async {
    final online = await widget.connectivity.refresh(forceProbe: true);
    if (!mounted) return false;
    if (online) return true;
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
    if (!mounted) return false;
    return widget.connectivity.refresh(forceProbe: true);
  }

  Future<void> _pushCloud() async {
    widget.sync?.schedulePush();
  }

  Future<void> _openCampaign() async {
    if (!await _requireOnline()) return;

    await widget.audioService.playClick();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorldSelectScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
        ),
      ),
    );
    if (!mounted) return;
    await widget.audioService.startMusic();
    if (!mounted) return;
    setState(_syncMeta);
    await _pushCloud();
  }

  Future<void> _openHangar() async {
    await widget.audioService.playClick();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HangarScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
        ),
      ),
    );
    if (!mounted) return;
    setState(_syncMeta);
    await _pushCloud();
  }

  Future<void> _openSettings() async {
    final auth = widget.auth;
    final sync = widget.sync;
    if (auth == null || sync == null) return;
    await widget.audioService.playClick();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
          auth: auth,
          sync: sync,
        ),
      ),
    );
    if (!mounted) return;
    setState(_syncMeta);
    await _pushCloud();
  }

  Future<void> _playDailyChallenge() async {
    if (!await _requireOnline()) return;
    await widget.audioService.playClick();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
          initialLevel: _challengeLevel,
          challengeMode: true,
        ),
      ),
    );
    if (!mounted) return;
    await widget.audioService.startMusic();
    if (!mounted) return;
    setState(_syncMeta);
    await _pushCloud();
  }

  Future<void> _claimDaily() async {
    if (_dailyBusy || _claimedDaily) return;
    setState(() {
      _dailyBusy = true;
      _dailyMessage = null;
    });
    final gained = await widget.scoreService.claimDailyReward();
    await widget.audioService.playClick();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _dailyBusy = false;
      _syncMeta();
      _dailyMessage = gained > 0
          ? '+$gained daily coins · streak $_streak'
          : 'Already claimed today';
    });
    await _pushCloud();
  }

  Future<void> _claimDailyDouble() async {
    if (_dailyBusy || !_claimedDaily || _claimedDouble) return;
    setState(() {
      _dailyBusy = true;
      _dailyMessage = null;
    });
    if (!await _requireOnline()) {
      if (!mounted) return;
      setState(() => _dailyBusy = false);
      return;
    }

    final outcome = await widget.adMob.showRewarded();
    if (!mounted) return;
    if (outcome != RewardedAdOutcome.rewarded) {
      setState(() {
        _dailyBusy = false;
        _dailyMessage = switch (outcome) {
          RewardedAdOutcome.dismissedWithoutReward =>
            'Watch the full ad to double the daily reward.',
          RewardedAdOutcome.noInternet => 'Internet required for ads.',
          _ => 'Ad unavailable. Try again.',
        };
      });
      return;
    }

    final gained = await widget.scoreService.claimDailyDoubleReward();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _dailyBusy = false;
      _syncMeta();
      _dailyMessage = gained > 0
          ? 'Daily doubled! +$gained coins'
          : 'Double already claimed';
    });
    await _pushCloud();
  }

  Future<void> _saveStreak() async {
    if (_dailyBusy || !_canSaveStreak) return;
    setState(() {
      _dailyBusy = true;
      _dailyMessage = null;
    });
    if (!await _requireOnline()) {
      if (!mounted) return;
      setState(() => _dailyBusy = false);
      return;
    }

    final outcome = await widget.adMob.showRewarded();
    if (!mounted) return;
    if (outcome != RewardedAdOutcome.rewarded) {
      setState(() {
        _dailyBusy = false;
        _dailyMessage = 'Watch the full ad to save your streak.';
      });
      return;
    }

    final ok = await widget.scoreService.saveStreakWithAd();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _dailyBusy = false;
      _syncMeta();
      _dailyMessage = ok
          ? 'Streak saved! Claim today’s reward.'
          : 'Could not save streak.';
    });
    await _pushCloud();
  }

  @override
  Widget build(BuildContext context) {
    final world = CampaignCatalog.themeForLevel(_unlockedLevel);
    final skin = widget.scoreService.equippedSkin;
    final progress = (_completed / CampaignCatalog.maxLevel).clamp(0.0, 1.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1438),
              AppColors.deepNavy,
              Color(0xFF050814),
              AppColors.midnight,
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _drift,
                builder: (context, _) => CustomPaint(
                  painter: _HomeStarfieldPainter(t: _drift.value),
                ),
              ),
            ),
            Positioned(
              top: -80,
              right: -60,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final glow = 0.12 + _pulse.value * 0.08;
                  return Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          skin.mid.withValues(alpha: glow),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 40,
              left: -90,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.violet.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(
                            coins: _totalCoins,
                            onSettings: widget.auth != null && widget.sync != null
                                ? _openSettings
                                : null,
                          ),
                          const SizedBox(height: 28),
                          _HeroBlock(
                            pulse: _pulse,
                            skin: skin,
                          ),
                          const SizedBox(height: 28),
                          _ContinueCard(
                            level: _unlockedLevel,
                            worldName: world.name,
                            completed: _completed,
                            maxLevel: CampaignCatalog.maxLevel,
                            progress: progress,
                            bestScore: _bestScore,
                            streak: _streak,
                            onPlay: _openCampaign,
                          ),
                          const SizedBox(height: 14),
                          _DailyCard(
                            challengeLevel: _challengeLevel,
                            streak: _streak,
                            claimed: _claimedDaily,
                            claimedDouble: _claimedDouble,
                            canSaveStreak: _canSaveStreak,
                            busy: _dailyBusy,
                            message: _dailyMessage,
                            baseReward: DailyChallengeLogic.baseRewardCoins,
                            onClaim: _claimDaily,
                            onDouble: _claimDailyDouble,
                            onSaveStreak: _saveStreak,
                            onPlay: _playDailyChallenge,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openHangar,
                              icon: const Icon(Icons.rocket_outlined),
                              label: const Text('HANGAR'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.player.withValues(alpha: 0.45),
                                ),
                                foregroundColor: AppColors.softWhite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.coins, required this.onSettings});

  final int coins;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.coin.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                color: AppColors.coin,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '$coins',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.coin,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (onSettings != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSettings,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.panel.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.panelBorder),
                ),
                child: const Icon(Icons.settings_rounded, size: 24),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.pulse, required this.skin});

  final AnimationController pulse;
  final ShipSkin skin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(pulse.value);
        return Transform.translate(
          offset: Offset(0, -4 + t * 8),
          child: child,
        );
      },
      child: Column(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(pulse.value);
              return Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [skin.primary, skin.mid, skin.deep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: skin.glow,
                      blurRadius: 22 + t * 18,
                      spreadRadius: 1 + t * 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  size: 52,
                  color: skin.accent,
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const Text(
            'TAP & DODGE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: AppColors.softWhite,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Dodge. Collect. Clear 50 levels.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.softWhite.withValues(alpha: 0.62),
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.level,
    required this.worldName,
    required this.completed,
    required this.maxLevel,
    required this.progress,
    required this.bestScore,
    required this.streak,
    required this.onPlay,
  });

  final int level;
  final String worldName;
  final int completed;
  final int maxLevel;
  final double progress;
  final int bestScore;
  final int streak;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.panel.withValues(alpha: 0.95),
                const Color(0xFF121A3F).withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(
              color: AppColors.player.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.player.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTINUE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: AppColors.player.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level $level',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$worldName · $completed / $maxLevel cleared',
                          style: TextStyle(
                            color: AppColors.softWhite.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          color: AppColors.accent,
                        ),
                        Center(
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MetaPill(
                    icon: Icons.emoji_events_rounded,
                    label: 'Best $bestScore',
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  _MetaPill(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Streak $streak',
                    color: AppColors.obstacle,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPlay,
                  child: const Text('PLAY CAMPAIGN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.challengeLevel,
    required this.streak,
    required this.claimed,
    required this.claimedDouble,
    required this.canSaveStreak,
    required this.busy,
    required this.message,
    required this.baseReward,
    required this.onClaim,
    required this.onDouble,
    required this.onSaveStreak,
    required this.onPlay,
  });

  final int challengeLevel;
  final int streak;
  final bool claimed;
  final bool claimedDouble;
  final bool canSaveStreak;
  final bool busy;
  final String? message;
  final int baseReward;
  final VoidCallback onClaim;
  final VoidCallback onDouble;
  final VoidCallback onSaveStreak;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Daily Challenge',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.player.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Lv $challengeLevel',
                  style: const TextStyle(
                    color: AppColors.player,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            canSaveStreak && !claimed
                ? 'You missed a day — save streak with an ad, then claim'
                : claimed
                ? (claimedDouble
                      ? 'Rewards claimed · streak $streak'
                      : 'Claimed · watch ad for +$baseReward more')
                : 'Free +$baseReward coins · keep your streak alive',
            style: TextStyle(
              color: AppColors.softWhite.withValues(alpha: 0.68),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.coin,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canSaveStreak && !claimed)
                _MiniAction(
                  label: busy ? '…' : 'SAVE STREAK',
                  onPressed: busy ? null : onSaveStreak,
                  filled: true,
                )
              else if (!claimed)
                _MiniAction(
                  label: busy ? '…' : 'CLAIM +$baseReward',
                  onPressed: busy ? null : onClaim,
                  filled: true,
                )
              else if (!claimedDouble)
                _MiniAction(
                  label: busy ? '…' : '2x DAILY AD',
                  onPressed: busy ? null : onDouble,
                  filled: true,
                ),
              _MiniAction(label: 'PLAY', onPressed: busy ? null : onPlay),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _HomeStarfieldPainter extends CustomPainter {
  _HomeStarfieldPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 48; i++) {
      final x = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final y = (baseY + t * size.height * (0.08 + rnd.nextDouble() * 0.12)) %
          size.height;
      final r = 0.6 + rnd.nextDouble() * 1.6;
      final twinkle = 0.25 + 0.55 * ((math.sin(t * math.pi * 2 + i) + 1) / 2);
      paint.color = AppColors.softWhite.withValues(alpha: twinkle * 0.55);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HomeStarfieldPainter oldDelegate) =>
      oldDelegate.t != t;
}
