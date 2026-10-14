import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/campaign/campaign_catalog.dart';
import '../game/meta/daily_challenge.dart';
import '../services/ad_policies.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/progress_sync_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'connection_required_screen.dart';
import 'game_screen.dart';
import 'hangar_screen.dart';
import 'privacy_policy_screen.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _bestScore = 0;
  int _totalCoins = 0;
  int _unlockedLevel = 1;
  int _completed = 0;
  int _streak = 0;
  int _challengeLevel = 1;
  bool _claimedDaily = false;
  bool _claimedDouble = false;
  bool _canSaveStreak = false;
  bool _muted = false;
  bool _loading = true;
  bool _dailyBusy = false;
  String? _dailyMessage;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
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
    _muted = widget.audioService.isMuted;
  }

  Future<void> _bootstrap() async {
    await widget.scoreService.init();
    await widget.audioService.init();
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
    // B07: after successful Retry pop, continue the original action.
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

  Future<void> _openAccount() async {
    final auth = widget.auth;
    final sync = widget.sync;
    if (auth == null || sync == null) return;
    await widget.audioService.playClick();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountScreen(
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
          // B11: isolated daily session — no campaign unlock / interstitial chain.
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

  Future<void> _toggleMute() async {
    await widget.audioService.toggleMute();
    if (!mounted) return;
    setState(() => _muted = widget.audioService.isMuted);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final world = CampaignCatalog.themeForLevel(_unlockedLevel);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101B45), AppColors.deepNavy, AppColors.midnight],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Privacy',
                              style: TextStyle(
                                color: AppColors.softWhite.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (widget.auth != null)
                            TextButton(
                              onPressed: _openAccount,
                              child: Text(
                                widget.auth!.isGoogle
                                    ? (widget.auth!.displayName ?? 'Account')
                                    : 'Guest · Account',
                                style: TextStyle(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: _muted ? 'Unmute' : 'Mute',
                            onPressed: _toggleMute,
                            icon: Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final t = Curves.easeInOut.transform(_pulse.value);
                          return Transform.scale(
                            scale: 0.96 + t * 0.04,
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    widget.scoreService.equippedSkin.primary,
                                    widget.scoreService.equippedSkin.mid,
                                    widget.scoreService.equippedSkin.deep,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        widget.scoreService.equippedSkin.glow,
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.rocket_launch_rounded,
                                size: 46,
                                color: widget.scoreService.equippedSkin.accent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'TAP & DODGE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: AppColors.softWhite,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '50 levels · daily rewards · hangar skins',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.softWhite.withValues(
                                  alpha: 0.72,
                                ),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatChip(
                            icon: Icons.emoji_events_rounded,
                            label: 'Best $_bestScore',
                            color: AppColors.accent,
                          ),
                          _StatChip(
                            icon: Icons.monetization_on_rounded,
                            label: 'Coins $_totalCoins',
                            color: AppColors.coin,
                          ),
                          _StatChip(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Streak $_streak',
                            color: AppColors.obstacle,
                          ),
                          _StatChip(
                            icon: Icons.flag_rounded,
                            label:
                                '$_completed/${CampaignCatalog.maxLevel} · ${world.name}',
                            color: AppColors.player,
                          ),
                        ],
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
                        child: ElevatedButton(
                          onPressed: _openCampaign,
                          child: const Text('PLAY CAMPAIGN'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openHangar,
                          icon: const Icon(Icons.rocket_outlined),
                          label: const Text('HANGAR'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Continue from level $_unlockedLevel',
                        style: TextStyle(
                          color: AppColors.softWhite.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Daily Challenge',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              Text(
                'Lv $challengeLevel',
                style: const TextStyle(
                  color: AppColors.player,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            canSaveStreak && !claimed
                ? 'You missed a day — save streak with an ad, then claim'
                : claimed
                ? (claimedDouble
                      ? 'Rewards claimed · streak $streak'
                      : 'Claimed · watch ad for +$baseReward more')
                : 'Free +$baseReward coins · keep your streak alive',
            style: TextStyle(
              color: AppColors.softWhite.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.coin,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // B06: when streak is savable, require SAVE before CLAIM.
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
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
