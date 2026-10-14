import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/campaign/campaign_catalog.dart';
import '../game/campaign/campaign_models.dart';
import '../game/session/game_phase.dart';
import '../game/tap_dodge_game.dart';
import '../services/ad_policies.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/connectivity_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';
import 'connection_required_screen.dart';

/// Hosts the Flame game and Flutter overlays.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.scoreService,
    required this.audioService,
    required this.connectivity,
    required this.adMob,
    this.initialLevel = 1,
    this.challengeMode = false,
  });

  final ScoreService scoreService;
  final AudioService audioService;
  final ConnectivityService connectivity;
  final AdMobService adMob;
  final int initialLevel;

  /// Daily / arena sessions — no campaign unlock chain (B11).
  final bool challengeMode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final TapDodgeGame _game;
  bool _autoStarted = false;
  bool _connectionLost = false;
  bool _rewardLoading = false;
  bool _clearDoubleLoading = false;
  bool _continueBusy = false;
  String? _rewardMessage;
  String? _clearDoubleMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = TapDodgeGame(
      scoreService: widget.scoreService,
      audioService: widget.audioService,
      initialLevel: widget.initialLevel,
    );
    widget.connectivity.hasInternet.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    final online = widget.connectivity.hasInternet.value;
    if (!mounted) return;
    if (!online) {
      final phase = _game.phase.value;
      if (phase == GamePhase.playing ||
          phase == GamePhase.countdown ||
          phase == GamePhase.levelIntro ||
          phase == GamePhase.sectionIntro ||
          phase == GamePhase.sectionComplete) {
        _game.suspendForConnectionLoss();
        setState(() => _connectionLost = true);
      }
    } else if (online && _connectionLost) {
      setState(() => _connectionLost = false);
    }
  }

  @override
  void dispose() {
    widget.connectivity.hasInternet.removeListener(_onConnectivityChanged);
    WidgetsBinding.instance.removeObserver(this);
    _game.disposeHostResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.adMob.isShowingAd) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _game.suspendForBackground();
    } else if (state == AppLifecycleState.resumed) {
      _game.resumeFromBackground();
      unawaited(widget.connectivity.refresh());
    }
  }

  Future<void> _ensureFirstStart() async {
    if (_autoStarted) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final online = await widget.connectivity.refresh(forceProbe: true);
    if (!mounted) return;
    if (!online) {
      // B02: do not latch _autoStarted so Retry can start the round.
      setState(() => _connectionLost = true);
      return;
    }
    _autoStarted = true;
    await _game.startRound(
      levelOverride: widget.initialLevel,
      challengeMode: widget.challengeMode,
    );
  }

  Future<void> _retryConnection() async {
    final ok = await widget.connectivity.refresh(forceProbe: true);
    if (!mounted) return;
    if (!ok) return;
    setState(() => _connectionLost = false);
    final phase = _game.phase.value;
    if (phase == GamePhase.paused ||
        phase == GamePhase.countdown ||
        phase == GamePhase.levelIntro ||
        phase == GamePhase.sectionIntro ||
        phase == GamePhase.sectionComplete) {
      _game.resumeAfterConnectionRestored();
    } else if (phase == GamePhase.ready || phase == GamePhase.loading) {
      await _ensureFirstStart();
    }
  }

  Future<void> _watchAdToContinue() async {
    if (_rewardLoading || !_game.canOfferRewardedContinue) return;
    setState(() {
      _rewardLoading = true;
      _rewardMessage = null;
    });

    final online = await widget.connectivity.refresh(forceProbe: true);
    if (!mounted) return;
    if (!online) {
      setState(() {
        _rewardLoading = false;
        _rewardMessage = 'Internet required to watch an ad.';
        _connectionLost = true;
      });
      return;
    }

    final outcome = await widget.adMob.showRewardedContinue();
    if (!mounted) return;

    switch (outcome) {
      case RewardedAdOutcome.rewarded:
        final ok = await _game.continueAfterRewardedAd();
        setState(() {
          _rewardLoading = false;
          _rewardMessage = ok
              ? null
              : 'Could not resume. Please restart the level.';
        });
      case RewardedAdOutcome.dismissedWithoutReward:
        setState(() {
          _rewardLoading = false;
          _rewardMessage = 'Watch the full ad to continue.';
        });
      case RewardedAdOutcome.failedToLoad:
      case RewardedAdOutcome.failedToShow:
        setState(() {
          _rewardLoading = false;
          _rewardMessage = 'Ad unavailable. Try again or restart.';
        });
      case RewardedAdOutcome.noInternet:
        setState(() {
          _rewardLoading = false;
          _rewardMessage = 'Internet required to watch an ad.';
          _connectionLost = true;
        });
      case RewardedAdOutcome.busy:
        setState(() {
          _rewardLoading = false;
          _rewardMessage = 'Please wait…';
        });
    }
  }

  Future<void> _continueCampaign() async {
    // B10: ignore double-taps while interstitial / advance is in flight.
    if (_continueBusy) return;
    _continueBusy = true;
    try {
      // Natural break: interstitial before next level (never after game-over).
      // Daily/challenge arena skips campaign interstitial chain.
      if (!widget.challengeMode && !_game.isChallengeMode) {
        await widget.adMob.maybeShowInterstitialAfterLevelClear();
      }
      if (!mounted) return;
      setState(() => _clearDoubleMessage = null);
      await _game.continueToNextLevel();
    } finally {
      _continueBusy = false;
    }
  }

  Future<void> _watchAdForClearDouble() async {
    if (_clearDoubleLoading ||
        _game.clearDoubleClaimed.value ||
        _game.lastClearDoublableCoins.value <= 0) {
      return;
    }
    setState(() {
      _clearDoubleLoading = true;
      _clearDoubleMessage = null;
    });

    final online = await widget.connectivity.refresh(forceProbe: true);
    if (!mounted) return;
    if (!online) {
      setState(() {
        _clearDoubleLoading = false;
        _clearDoubleMessage = 'Internet required to watch an ad.';
        _connectionLost = true;
      });
      return;
    }

    final outcome = await widget.adMob.showRewarded();
    if (!mounted) return;

    switch (outcome) {
      case RewardedAdOutcome.rewarded:
        final gained = await _game.claimClearCoinDouble();
        setState(() {
          _clearDoubleLoading = false;
          _clearDoubleMessage = gained > 0
              ? '2x active — Doubled! +$gained coins'
              : 'Already claimed.';
        });
      case RewardedAdOutcome.dismissedWithoutReward:
        setState(() {
          _clearDoubleLoading = false;
          _clearDoubleMessage = 'Watch the full ad to double coins.';
        });
      case RewardedAdOutcome.failedToLoad:
      case RewardedAdOutcome.failedToShow:
        setState(() {
          _clearDoubleLoading = false;
          _clearDoubleMessage = 'Ad unavailable. Update WebView / try again.';
        });
      case RewardedAdOutcome.noInternet:
        setState(() {
          _clearDoubleLoading = false;
          _clearDoubleMessage = 'Internet required to watch an ad.';
          _connectionLost = true;
        });
      case RewardedAdOutcome.busy:
        setState(() {
          _clearDoubleLoading = false;
          _clearDoubleMessage = 'Please wait…';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                GameWidget(
                  game: _game,
                  loadingBuilder: (_) => Container(
                    color: AppColors.midnight,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  ),
                ),
                _OverlayLayer(
                  game: _game,
                  onReadyToStart: _ensureFirstStart,
                  onContinueCampaign: _continueCampaign,
                  onWatchAdToContinue: _watchAdToContinue,
                  onWatchAdForClearDouble: _watchAdForClearDouble,
                  rewardLoading: _rewardLoading,
                  rewardMessage: _rewardMessage,
                  clearDoubleLoading: _clearDoubleLoading,
                  clearDoubleMessage: _clearDoubleMessage,
                ),
                _Hud(
                  game: _game,
                  onBack: () => Navigator.of(context).maybePop(),
                  onMute: () async {
                    await widget.audioService.toggleMute();
                    setState(() {});
                  },
                  muted: widget.audioService.isMuted,
                ),
                if (_connectionLost)
                  Positioned.fill(
                    child: ConnectionRequiredScreen(
                      asOverlay: true,
                      onRetry: _retryConnection,
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

class _Hud extends StatelessWidget {
  const _Hud({
    required this.game,
    required this.onBack,
    required this.onMute,
    required this.muted,
  });

  final TapDodgeGame game;
  final VoidCallback onBack;
  final VoidCallback onMute;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      right: 8,
      top: 8,
      child: Column(
        children: [
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: game.levelNumber,
                  builder: (_, level, _) {
                    return ValueListenableBuilder<int>(
                      valueListenable: game.sectionIndex,
                      builder: (_, section, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: game.score,
                          builder: (_, score, _) {
                            return _Pill(
                              child: Text(
                                'Lv $level · S${section + 1}   $score',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: game.doubleCoinsActive,
                builder: (_, doubleOn, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (doubleOn) ...[
                        _Pill(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: const Text(
                            '2x',
                            style: TextStyle(
                              color: AppColors.coin,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      ValueListenableBuilder<int>(
                        valueListenable: game.sectionCoins,
                        builder: (_, sectionGot, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: game.sectionCoinsRequired,
                            builder: (_, sectionNeed, _) {
                              return ValueListenableBuilder<int>(
                                valueListenable: game.runCoins,
                                builder: (_, coins, _) {
                                  return _Pill(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.monetization_on_rounded,
                                          color: AppColors.coin,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$sectionGot/$sectionNeed',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.coin,
                                          ),
                                        ),
                                        Text(
                                          ' · $coins',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.coin.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 6),
              _RoundIconButton(
                icon: muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                onPressed: onMute,
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<GamePhase>(
                valueListenable: game.phase,
                builder: (_, phase, _) {
                  final canPause =
                      phase == GamePhase.playing || phase == GamePhase.paused;
                  return _RoundIconButton(
                    icon: phase == GamePhase.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onPressed: canPause ? game.togglePause : null,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<double>(
            valueListenable: game.levelProgress,
            builder: (_, progress, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: Colors.black38,
                  color: AppColors.player,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverlayLayer extends StatelessWidget {
  const _OverlayLayer({
    required this.game,
    required this.onReadyToStart,
    required this.onContinueCampaign,
    required this.onWatchAdToContinue,
    required this.onWatchAdForClearDouble,
    required this.rewardLoading,
    required this.rewardMessage,
    required this.clearDoubleLoading,
    required this.clearDoubleMessage,
  });

  final TapDodgeGame game;
  final VoidCallback onReadyToStart;
  final Future<void> Function() onContinueCampaign;
  final Future<void> Function() onWatchAdToContinue;
  final Future<void> Function() onWatchAdForClearDouble;
  final bool rewardLoading;
  final String? rewardMessage;
  final bool clearDoubleLoading;
  final String? clearDoubleMessage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GamePhase>(
      valueListenable: game.phase,
      builder: (context, phase, _) {
        if (phase == GamePhase.loading || phase == GamePhase.ready) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onReadyToStart());
        }

        if (phase == GamePhase.levelIntro) {
          return ValueListenableBuilder<String>(
            valueListenable: game.levelName,
            builder: (_, name, _) {
              return ValueListenableBuilder<int>(
                valueListenable: game.levelNumber,
                builder: (_, number, _) {
                  return ValueListenableBuilder(
                    valueListenable: game.themeNotifier,
                    builder: (_, theme, _) {
                      return _DimOverlay(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(theme.icon, color: theme.primary, size: 42),
                            const SizedBox(height: 10),
                            Text(
                              theme.name.toUpperCase(),
                              style: TextStyle(
                                color: theme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'LEVEL $number',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ValueListenableBuilder<String>(
                              valueListenable: game.levelObjective,
                              builder: (_, objective, _) => Text(
                                objective,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        }

        if (phase == GamePhase.sectionIntro ||
            phase == GamePhase.sectionComplete) {
          return ValueListenableBuilder<String>(
            valueListenable: game.sectionName,
            builder: (_, name, _) {
              return ValueListenableBuilder<String>(
                valueListenable: game.sectionBlurb,
                builder: (_, blurb, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: game.sectionIndex,
                    builder: (_, index, _) {
                      return ValueListenableBuilder<int>(
                        valueListenable: game.sectionCount,
                        builder: (_, count, _) {
                          return ValueListenableBuilder(
                            valueListenable: game.themeNotifier,
                            builder: (_, theme, _) {
                              final icon = _sectionIcon(
                                game.currentSection.mechanic,
                              );
                              return _DimOverlay(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        color: theme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        border: Border.all(
                                          color: theme.primary.withValues(
                                            alpha: 0.55,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: theme.primary,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'SECTION ${index + 1}/$count',
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      blurb,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ValueListenableBuilder<int>(
                                      valueListenable:
                                          game.sectionCoinsRequired,
                                      builder: (_, need, _) => Text(
                                        'Collect $need coins · Keep moving · Dodge hazards',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: theme.accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        }

        if (phase == GamePhase.countdown) {
          return ValueListenableBuilder<int>(
            valueListenable: game.countdown,
            builder: (_, value, _) {
              return _DimOverlay(
                child: Text(
                  value > 0 ? '$value' : 'GO!',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          );
        }

        if (phase == GamePhase.paused) {
          return _DimOverlay(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PAUSED',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: game.resumeGame,
                  child: const Text('RESUME'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: game.restartLevel,
                  child: const Text('RESTART'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Level Select',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          );
        }

        if (phase == GamePhase.levelComplete) {
          return ValueListenableBuilder<int>(
            valueListenable: game.lastRewardCoins,
            builder: (_, rewardCoins, _) {
              return ValueListenableBuilder<int>(
                valueListenable: game.lastRewardScore,
                builder: (_, rewardScore, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: game.levelNumber,
                    builder: (_, number, _) {
                      final challenge = game.isChallengeMode;
                      final isCampaignFinale =
                          !challenge && number >= CampaignCatalog.maxLevel;
                      return _DimOverlay(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              challenge ? 'ARENA CLEAR!' : 'LEVEL CLEAR!',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: AppColors.player,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              challenge
                                  ? 'Replay Arena complete'
                                  : 'Level $number complete',
                            ),
                            const SizedBox(height: 14),
                            Text(
                              rewardCoins > 0
                                  ? '+$rewardScore score   +$rewardCoins clear coins'
                                  : '+$rewardScore score   Replay clear',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            _ClearDoubleAdBlock(
                              game: game,
                              loading: clearDoubleLoading,
                              message: clearDoubleMessage,
                              onWatch: onWatchAdForClearDouble,
                            ),
                            const SizedBox(height: 16),
                            if (challenge) ...[
                              ElevatedButton(
                                onPressed: () =>
                                    game.startRound(challengeMode: true),
                                child: const Text('PLAY AGAIN'),
                              ),
                            ] else if (isCampaignFinale) ...[
                              ElevatedButton(
                                onPressed: () => onContinueCampaign(),
                                child: const Text('VIEW VICTORY'),
                              ),
                            ] else ...[
                              ElevatedButton(
                                onPressed: () => onContinueCampaign(),
                                child: const Text('CONTINUE'),
                              ),
                            ],
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: Text(
                                challenge ? 'World Select' : 'Level Select',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        }

        if (phase == GamePhase.worldComplete) {
          return ValueListenableBuilder<String>(
            valueListenable: game.lastWorldName,
            builder: (_, worldName, _) {
              return ValueListenableBuilder<int>(
                valueListenable: game.lastWorldRewardCoins,
                builder: (_, worldCoins, _) {
                  return ValueListenableBuilder(
                    valueListenable: game.themeNotifier,
                    builder: (_, theme, _) {
                      return _DimOverlay(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(theme.icon, color: theme.accent, size: 56),
                            const SizedBox(height: 12),
                            const Text(
                              'WORLD CLEAR!',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              worldName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: theme.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              worldCoins > 0
                                  ? 'Milestone reward +$worldCoins coins'
                                  : 'World already claimed',
                              style: const TextStyle(
                                color: AppColors.coin,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            _ClearDoubleAdBlock(
                              game: game,
                              loading: clearDoubleLoading,
                              message: clearDoubleMessage,
                              onWatch: onWatchAdForClearDouble,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => onContinueCampaign(),
                              child: const Text('CONTINUE CAMPAIGN'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text(
                                'World Select',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        }

        if (phase == GamePhase.campaignComplete) {
          return ValueListenableBuilder<int>(
            valueListenable: game.lastWorldRewardCoins,
            builder: (_, worldCoins, _) {
              return _DimOverlay(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.accent,
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CAMPAIGN COMPLETE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'You cleared all 50 levels of Tap & Dodge.',
                      textAlign: TextAlign.center,
                    ),
                    if (worldCoins > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Final world bonus +$worldCoins coins',
                        style: const TextStyle(
                          color: AppColors.coin,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    _ClearDoubleAdBlock(
                      game: game,
                      loading: clearDoubleLoading,
                      message: clearDoubleMessage,
                      onWatch: onWatchAdForClearDouble,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => game.startRound(
                        levelOverride: CampaignCatalog.maxLevel,
                      ),
                      child: const Text('REPLAY LEVEL 50'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => game.startRound(challengeMode: true),
                      child: const Text('REPLAY ARENA'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text(
                        'World Select',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }

        if (phase == GamePhase.gameOver) {
          return ValueListenableBuilder<int>(
            valueListenable: game.score,
            builder: (_, score, _) {
              return ValueListenableBuilder<int>(
                valueListenable: game.bestScore,
                builder: (_, best, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: game.runCoins,
                    builder: (_, coins, _) {
                      return ValueListenableBuilder<int>(
                        valueListenable: game.levelNumber,
                        builder: (_, level, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: game.sectionIndex,
                            builder: (_, section, _) {
                              final canContinue = game.canOfferRewardedContinue;
                              return _DimOverlay(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'GAME OVER',
                                      style: TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Level $level · Section ${section + 1}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Score  $score',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Coins  $coins',
                                      style: const TextStyle(
                                        color: AppColors.coin,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text('Best  $best'),
                                    if (rewardMessage != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        rewardMessage!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.obstacle,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 22),
                                    if (canContinue)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: rewardLoading
                                              ? null
                                              : () => onWatchAdToContinue(),
                                          icon: rewardLoading
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.ondemand_video_rounded,
                                                ),
                                          label: Text(
                                            rewardLoading
                                                ? 'LOADING AD…'
                                                : 'WATCH AD TO CONTINUE',
                                          ),
                                        ),
                                      ),
                                    if (canContinue) const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: game.restartLevel,
                                        child: const Text('RESTART LEVEL'),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      child: const Text(
                                        'Level Select',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _ClearDoubleAdBlock extends StatelessWidget {
  const _ClearDoubleAdBlock({
    required this.game,
    required this.loading,
    required this.message,
    required this.onWatch,
  });

  final TapDodgeGame game;
  final bool loading;
  final String? message;
  final Future<void> Function() onWatch;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.lastClearDoublableCoins,
      builder: (_, amount, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: game.clearDoubleClaimed,
          builder: (_, claimed, _) {
            if (amount <= 0) return const SizedBox(height: 8);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: claimed ? AppColors.coin : AppColors.obstacle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!claimed)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : () => onWatch(),
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.ondemand_video_rounded),
                      label: Text(
                        loading ? 'LOADING AD…' : '2x COINS (+$amount)',
                      ),
                    ),
                  )
                else if (message == null)
                  const Text(
                    'Coins doubled',
                    style: TextStyle(
                      color: AppColors.coin,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

IconData _sectionIcon(SectionMechanic mechanic) {
  return switch (mechanic) {
    SectionMechanic.none => Icons.shield_moon_rounded,
    SectionMechanic.denseCoins => Icons.monetization_on_rounded,
    SectionMechanic.laneSweep => Icons.alt_route_rounded,
    SectionMechanic.toxicBand => Icons.science_rounded,
    SectionMechanic.riftPulse => Icons.bolt_rounded,
    SectionMechanic.finaleStorm => Icons.local_fire_department_rounded,
  };
}

class _DimOverlay extends StatelessWidget {
  const _DimOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: child,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.softWhite, size: 22),
        ),
      ),
    );
  }
}
