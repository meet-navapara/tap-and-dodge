import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/ad_policies.dart';
import '../services/audio_service.dart';
import '../services/score_service.dart';
import 'campaign/campaign_catalog.dart';
import 'campaign/campaign_models.dart';
import 'campaign/campaign_progress.dart';
import 'components/coin.dart';
import 'components/obstacle.dart';
import 'components/pickup_burst.dart';
import 'components/player.dart';
import 'components/reward_banner.dart';
import 'components/starfield_background.dart';
import 'components/toxic_band.dart';
import 'levels/level_config.dart';
import 'playfield.dart';
import 'rules/scoring_rules.dart';
import 'rules/section_objectives.dart';
import 'session/game_phase.dart';

/// Flame game world for the 50-level Tap & Dodge campaign.
class TapDodgeGame extends FlameGame
    with HasCollisionDetection, PanDetector, KeyboardEvents {
  TapDodgeGame({
    required this.scoreService,
    required this.audioService,
    this.initialLevel = 1,
  });

  final ScoreService scoreService;
  final AudioService audioService;
  final int initialLevel;
  final Random _random = Random();

  late Player player;
  late CampaignLevel level;
  late SectionConfig currentSection;
  late ToxicBand toxicBand;

  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.loading);
  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> bestScore = ValueNotifier(0);
  final ValueNotifier<int> countdown = ValueNotifier(0);
  final ValueNotifier<int> runCoins = ValueNotifier(0);
  final ValueNotifier<int> totalCoins = ValueNotifier(0);
  final ValueNotifier<int> levelNumber = ValueNotifier(1);
  final ValueNotifier<double> levelProgress = ValueNotifier(0);
  final ValueNotifier<String> levelName = ValueNotifier('First Flight');
  final ValueNotifier<String> levelObjective = ValueNotifier('');
  final ValueNotifier<int> lastRewardCoins = ValueNotifier(0);
  final ValueNotifier<int> lastRewardScore = ValueNotifier(0);

  /// Run coins + first-clear bonus eligible for a one-time post-clear 2x ad.
  final ValueNotifier<int> lastClearDoublableCoins = ValueNotifier(0);
  final ValueNotifier<bool> clearDoubleClaimed = ValueNotifier(false);
  final ValueNotifier<int> lastWorldRewardCoins = ValueNotifier(0);
  final ValueNotifier<String> lastWorldName = ValueNotifier('');
  final ValueNotifier<int> sectionIndex = ValueNotifier(0);
  final ValueNotifier<int> sectionCount = ValueNotifier(2);
  final ValueNotifier<String> sectionName = ValueNotifier('');
  final ValueNotifier<String> sectionBlurb = ValueNotifier('');
  final ValueNotifier<double> sectionProgress = ValueNotifier(0);
  final ValueNotifier<int> sectionCoins = ValueNotifier(0);
  final ValueNotifier<int> sectionCoinsRequired = ValueNotifier(2);
  final ValueNotifier<WorldTheme> themeNotifier = ValueNotifier(
    CampaignCatalog.worlds.first,
  );

  double survivalSeconds = 0;
  double sectionSeconds = 0;
  double _obstacleCooldown = 0;
  double _coinCooldown = 0;
  double _sectionTravel = 0;
  int _sectionCoinCount = 0;
  int _spawnWave = 0;
  bool _roundActive = false;
  bool _startingRound = false;
  bool _levelCompletionLocked = false;
  bool _sectionCompletionLocked = false;
  bool _gameOverLocked = false;
  bool _challengeMode = false;
  bool _continueUsedThisAttempt = false;
  bool _runCoinsBanked = false;
  bool _clearDoubleClaimed = false;
  int _clearDoublableCoins = 0;
  double _invulnerabilitySeconds = 0;
  double _doubleCoinSeconds = 0;
  final RewardedContinuePolicy _continuePolicy = const RewardedContinuePolicy();
  final ValueNotifier<bool> doubleCoinsActive = ValueNotifier(false);

  double _countdownTick = 0;
  double _gameOverSettle = 0;
  double _levelIntroTick = 0;
  double _sectionIntroTick = 0;
  double _sectionHandoffTick = 0;
  bool _pendingSectionIntro = false;

  static const double _keyboardSpeed = 280;
  final Set<LogicalKeyboardKey> _keysDown = {};

  WorldTheme get worldTheme => themeNotifier.value;
  bool get isChallengeMode => _challengeMode;
  bool get canOfferRewardedContinue =>
      _continuePolicy.canContinue(_continueUsedThisAttempt ? 1 : 0);
  bool get isInvulnerable => _invulnerabilitySeconds > 0;
  bool get hasDoubleCoins => _doubleCoinSeconds > 0;

  bool get isGameplayActive =>
      phase.value == GamePhase.playing &&
      _roundActive &&
      !_sectionCompletionLocked &&
      !_levelCompletionLocked &&
      !_gameOverLocked;

  bool get canControlPlayer =>
      phase.value == GamePhase.playing || phase.value == GamePhase.countdown;

  static final Set<LogicalKeyboardKey> _moveKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyS,
  };

  bool _lifecycleSuspended = false;

  GameSessionSnapshot get snapshot => GameSessionSnapshot(
    phase: phase.value,
    score: score.value,
    bestScore: bestScore.value,
    countdown: countdown.value,
    survivalSeconds: survivalSeconds,
    levelNumber: levelNumber.value,
    runCoins: runCoins.value,
    sectionIndex: sectionIndex.value,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await scoreService.init();
    await audioService.init();
    bestScore.value = scoreService.bestScore;
    totalCoins.value = scoreService.totalCoins;

    _applyLevel(CampaignCatalog.byNumber(initialLevel));

    camera.viewfinder.anchor = Anchor.topLeft;
    add(StarfieldBackground());
    toxicBand = ToxicBand();
    add(toxicBand);

    player = Player(position: Vector2(size.x / 2, size.y * 0.72));
    add(player);
    player.clampToBounds();

    phase.value = GamePhase.ready;
  }

  void _applyLevel(CampaignLevel config) {
    level = config;
    levelNumber.value = config.number;
    levelName.value = config.name;
    levelObjective.value = config.objectiveText;
    sectionCount.value = config.sectionCount;
    themeNotifier.value = CampaignCatalog.themeForWorld(config.world);
    _applySection(config.sections.first);
    levelProgress.value = 0;
  }

  void _applySection(SectionConfig section) {
    currentSection = section;
    sectionIndex.value = section.index;
    sectionName.value = section.name;
    sectionBlurb.value = section.blurb;
    sectionProgress.value = 0;
    sectionSeconds = 0;
    _sectionTravel = 0;
    _sectionCoinCount = 0;
    _spawnWave = 0;
    sectionCoins.value = 0;
    sectionCoinsRequired.value = section.requiredCoins;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!hasLayout) return;
    if (isMounted && player.isMounted) {
      player.clampToBounds();
    }
  }

  Future<void> startRound({
    int? levelOverride,
    bool challengeMode = false,
  }) async {
    if (_startingRound) return;
    if (phase.value == GamePhase.playing ||
        phase.value == GamePhase.countdown ||
        phase.value == GamePhase.levelIntro ||
        phase.value == GamePhase.sectionIntro) {
      return;
    }

    _clearTransientState();
    _startingRound = true;
    resumeEngine();

    _challengeMode = challengeMode;
    if (challengeMode && levelOverride == null) {
      // Post-campaign Replay Arena (no specific level requested).
      _applyLevel(_challengeLevel());
    } else {
      // Campaign levels, or daily challenge at a concrete levelOverride.
      final maxAllowed = challengeMode
          ? CampaignCatalog.maxLevel
          : scoreService.unlockedLevel;
      final n = (levelOverride ?? initialLevel)
          .clamp(1, maxAllowed)
          .toInt()
          .clamp(1, CampaignCatalog.maxLevel);
      _applyLevel(CampaignCatalog.byNumber(n));
    }

    await _resetWorld(keepScore: false);
    _continueUsedThisAttempt = false;
    _runCoinsBanked = false;
    _invulnerabilitySeconds = 0;
    _doubleCoinSeconds = 0;
    doubleCoinsActive.value = false;
    phase.value = GamePhase.levelIntro;
    _levelIntroTick = 1.7;
    await audioService.playClick();
  }

  CampaignLevel _challengeLevel() {
    final base = CampaignCatalog.byNumber(50);
    return CampaignLevel(
      number: 50,
      name: 'Replay Arena',
      world: CampaignWorld.finalFrontier,
      sections: base.sections,
      completionCoinReward: 12,
      completionScoreReward: 25,
    );
  }

  Future<void> continueToNextLevel() async {
    if (phase.value != GamePhase.levelComplete &&
        phase.value != GamePhase.worldComplete) {
      return;
    }
    resumeEngine();

    // Challenge / daily sessions replay the same level (no campaign advance).
    if (_challengeMode) {
      await startRound(levelOverride: level.number, challengeMode: true);
      return;
    }

    if (level.number >= CampaignCatalog.maxLevel) {
      phase.value = GamePhase.campaignComplete;
      pauseEngine();
      return;
    }

    await startRound(levelOverride: level.number + 1);
  }

  void _beginSectionIntro() {
    phase.value = GamePhase.sectionIntro;
    _sectionIntroTick = 1.55;
    _startingRound = true;
  }

  void _beginCountdown() {
    phase.value = GamePhase.countdown;
    countdown.value = 3;
    _countdownTick = 1;
  }

  void _beginPlaying() {
    _roundActive = true;
    _levelCompletionLocked = false;
    _sectionCompletionLocked = false;
    _gameOverLocked = false;
    _keysDown.clear();
    sectionSeconds = 0;
    _obstacleCooldown = 0.4;
    _coinCooldown = 0.2;
    phase.value = GamePhase.playing;
    _startingRound = false;
    audioService.startMusic();
  }

  void _clearFieldEntities() {
    children
        .whereType<Obstacle>()
        .toList(growable: false)
        .forEach((c) => c.removeFromParent());
    children
        .whereType<Coin>()
        .toList(growable: false)
        .forEach((c) => c.removeFromParent());
    children
        .whereType<PickupBurst>()
        .toList(growable: false)
        .forEach((c) => c.removeFromParent());
  }

  Future<void> _resetWorld({required bool keepScore}) async {
    _roundActive = false;
    survivalSeconds = 0;
    sectionSeconds = 0;
    _obstacleCooldown = 0;
    _coinCooldown = 0;
    _sectionTravel = 0;
    _sectionCoinCount = 0;
    _spawnWave = 0;
    _keysDown.clear();
    _levelCompletionLocked = false;
    _sectionCompletionLocked = false;
    if (!keepScore) {
      score.value = 0;
      runCoins.value = 0;
    }
    levelProgress.value = 0;
    sectionProgress.value = 0;
    sectionCoins.value = 0;
    sectionCoinsRequired.value = currentSection.requiredCoins;

    children
        .whereType<Obstacle>()
        .toList(growable: false)
        .forEach((c) => c.removeFromParent());
    children
        .whereType<Coin>()
        .toList(growable: false)
        .forEach((c) => c.removeFromParent());
    children
        .whereType<PickupBurst>()
        .toList(growable: false)
        .forEach((c) => c.removeFromParent());

    player.resetToStart();
  }

  void pauseGame() {
    if (phase.value != GamePhase.playing) return;
    _keysDown.clear();
    phase.value = GamePhase.paused;
    pauseEngine();
    audioService.pauseMusic();
  }

  void resumeGame() {
    if (phase.value != GamePhase.paused) return;
    _keysDown.clear();
    phase.value = GamePhase.playing;
    resumeEngine();
    audioService.resumeMusic();
  }

  bool get _canSoftSuspend =>
      phase.value == GamePhase.levelIntro ||
      phase.value == GamePhase.sectionIntro ||
      phase.value == GamePhase.countdown ||
      phase.value == GamePhase.sectionComplete;

  /// Freeze intro/countdown timers when the app is backgrounded.
  void suspendForBackground() {
    if (phase.value == GamePhase.playing) {
      pauseGame();
      return;
    }
    if (_canSoftSuspend) {
      _lifecycleSuspended = true;
      _keysDown.clear();
      pauseEngine();
    }
  }

  void resumeFromBackground() {
    if (!_lifecycleSuspended) return;
    _lifecycleSuspended = false;
    _keysDown.clear();
    if (_canSoftSuspend) {
      resumeEngine();
    }
  }

  /// Freeze play/countdown when connectivity drops (B03).
  void suspendForConnectionLoss() {
    _keysDown.clear();
    if (phase.value == GamePhase.playing) {
      pauseGame();
      return;
    }
    if (_canSoftSuspend) {
      _lifecycleSuspended = true;
      pauseEngine();
    }
  }

  /// Resume after connectivity returns (if soft-suspended).
  void resumeAfterConnectionRestored() {
    if (phase.value == GamePhase.paused) {
      resumeGame();
      return;
    }
    if (_lifecycleSuspended && _canSoftSuspend) {
      _lifecycleSuspended = false;
      _keysDown.clear();
      resumeEngine();
    }
  }

  void togglePause() {
    if (phase.value == GamePhase.playing) {
      pauseGame();
    } else if (phase.value == GamePhase.paused) {
      resumeGame();
    }
  }

  Future<void> restartLevel() async {
    if (phase.value == GamePhase.countdown ||
        phase.value == GamePhase.levelIntro ||
        phase.value == GamePhase.sectionIntro) {
      return;
    }
    if (phase.value == GamePhase.playing || phase.value == GamePhase.paused) {
      phase.value = GamePhase.gameOver;
      pauseEngine();
    }
    await _bankRunCoinsIfNeeded();
    _startingRound = false;
    await startRound(
      levelOverride: level.number,
      challengeMode: _challengeMode,
    );
  }

  /// Resume the same level/section after a confirmed rewarded ad.
  Future<bool> continueAfterRewardedAd() async {
    if (phase.value != GamePhase.gameOver) return false;
    if (!canOfferRewardedContinue) return false;

    _continueUsedThisAttempt = true;
    _gameOverLocked = false;
    _levelCompletionLocked = false;
    _sectionCompletionLocked = false;
    _pendingSectionIntro = false;
    _keysDown.clear();
    _clearFieldEntities();

    player.resetToStart();

    // B05: if section goals were already met at death, clear cleanly without
    // carrying free shield/2x into the next section.
    if (_sectionObjectivesMet) {
      _invulnerabilitySeconds = 0;
      _doubleCoinSeconds = 0;
      doubleCoinsActive.value = false;
      _roundActive = false;
      phase.value = GamePhase.playing;
      resumeEngine();
      await audioService.startMusic();
      await _onSectionComplete();
      return true;
    }

    _invulnerabilitySeconds = 2.4;
    _doubleCoinSeconds = 10;
    doubleCoinsActive.value = true;
    _obstacleCooldown = 0.85;
    _coinCooldown = 0.35;
    _roundActive = true;
    phase.value = GamePhase.playing;
    resumeEngine();
    await audioService.startMusic();
    // Visible continue feedback — shield + 2x reward banners.
    add(
      RewardBanner(
        label: 'SHIELD ACTIVE',
        accent: const Color(0xFF39F3FF),
        duration: 1.4,
        position: Vector2(size.x / 2, size.y * 0.32),
      ),
    );
    add(
      RewardBanner(
        label: '2x COINS ×10s',
        accent: const Color(0xFFFFD76A),
        duration: 1.9,
        position: Vector2(size.x / 2, size.y * 0.42),
      ),
    );
    return true;
  }

  Future<void> _bankRunCoinsIfNeeded() async {
    if (_runCoinsBanked || runCoins.value <= 0) return;
    _runCoinsBanked = true;
    await scoreService.addCoins(runCoins.value);
    totalCoins.value = scoreService.totalCoins;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (!canControlPlayer) return;
    final delta = info.delta.global;
    final moved = player.moveByDelta(delta.x, delta.y);
    _registerTravel(moved);
  }

  @override
  void onPanEnd(DragEndInfo info) {}

  @override
  void onPanCancel() {}

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _keysDown
      ..clear()
      ..addAll(keysPressed.where(_moveKeys.contains));
    final touchesMove =
        _moveKeys.contains(event.logicalKey) || _keysDown.isNotEmpty;
    return touchesMove ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _applyKeyboardMovement(double dt) {
    if (!canControlPlayer || _keysDown.isEmpty) return;

    var dx = 0.0;
    var dy = 0.0;
    if (_keysDown.contains(LogicalKeyboardKey.arrowLeft) ||
        _keysDown.contains(LogicalKeyboardKey.keyA)) {
      dx -= 1;
    }
    if (_keysDown.contains(LogicalKeyboardKey.arrowRight) ||
        _keysDown.contains(LogicalKeyboardKey.keyD)) {
      dx += 1;
    }
    if (_keysDown.contains(LogicalKeyboardKey.arrowUp) ||
        _keysDown.contains(LogicalKeyboardKey.keyW)) {
      dy -= 1;
    }
    if (_keysDown.contains(LogicalKeyboardKey.arrowDown) ||
        _keysDown.contains(LogicalKeyboardKey.keyS)) {
      dy += 1;
    }
    if (dx == 0 && dy == 0) return;

    final len = sqrt(dx * dx + dy * dy);
    dx = dx / len * _keyboardSpeed * dt;
    dy = dy / len * _keyboardSpeed * dt;
    final moved = player.moveByDelta(dx, dy);
    _registerTravel(moved);
  }

  void _registerTravel(double distance) {
    if (!_roundActive || phase.value != GamePhase.playing) return;
    if (distance <= 0) return;
    _sectionTravel += distance;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (phase.value == GamePhase.levelIntro) {
      _levelIntroTick -= dt;
      if (_levelIntroTick <= 0) {
        _beginSectionIntro();
      }
      return;
    }

    if (phase.value == GamePhase.sectionIntro) {
      _sectionIntroTick -= dt;
      if (_sectionIntroTick <= 0) {
        _beginCountdown();
      }
      return;
    }

    // Engine-tick handoff (respects pauseEngine / lifecycle) — never wall-clock.
    if (phase.value == GamePhase.sectionComplete) {
      if (_pendingSectionIntro && _sectionHandoffTick > 0) {
        _sectionHandoffTick -= dt;
        if (_sectionHandoffTick <= 0) {
          _pendingSectionIntro = false;
          if (!_gameOverLocked && !_levelCompletionLocked) {
            _beginSectionIntro();
          }
        }
      }
      return;
    }

    if (phase.value == GamePhase.countdown) {
      _countdownTick -= dt;
      if (_countdownTick <= 0) {
        final next = countdown.value - 1;
        if (next <= 0) {
          countdown.value = 0;
          _beginPlaying();
        } else {
          countdown.value = next;
          _countdownTick = 1;
        }
      }
      return;
    }

    if (phase.value == GamePhase.gameOver && _gameOverSettle > 0) {
      _gameOverSettle -= dt;
      if (_gameOverSettle <= 0) {
        pauseEngine();
      }
      return;
    }

    if (!_roundActive || phase.value != GamePhase.playing) return;

    final wasInvulnerable = _invulnerabilitySeconds > 0;
    if (_invulnerabilitySeconds > 0) {
      _invulnerabilitySeconds = (_invulnerabilitySeconds - dt).clamp(0.0, 10.0);
    }
    // B04: re-check overlap when shield expires (onCollisionStart won't re-fire).
    if (wasInvulnerable && _invulnerabilitySeconds <= 0) {
      _resolveStickyHazardOverlap();
      if (_gameOverLocked || phase.value != GamePhase.playing) return;
    }
    if (_doubleCoinSeconds > 0) {
      _doubleCoinSeconds = (_doubleCoinSeconds - dt).clamp(0.0, 30.0);
      if (_doubleCoinSeconds <= 0 && doubleCoinsActive.value) {
        doubleCoinsActive.value = false;
      }
    }

    _applyKeyboardMovement(dt);

    survivalSeconds += dt;
    sectionSeconds += dt;
    _updateProgress();

    _obstacleCooldown -= dt;
    if (_obstacleCooldown <= 0) {
      _trySpawnObstacleWave();
      var interval = currentSection.obstacleInterval;
      if (currentSection.mechanic == SectionMechanic.finaleStorm ||
          currentSection.mechanic == SectionMechanic.riftPulse) {
        interval *= 0.82;
      }
      // Overtime pressure if the player is stalling on coin/move goals.
      if (sectionSeconds > currentSection.durationSeconds) {
        interval *= 0.75;
      }
      _obstacleCooldown = interval;
    }

    _coinCooldown -= dt;
    if (_coinCooldown <= 0) {
      _trySpawnCoin();
      var interval = currentSection.coinInterval;
      if (currentSection.mechanic == SectionMechanic.denseCoins) {
        interval *= 0.7;
      }
      if (_sectionCoinCount < currentSection.requiredCoins) {
        interval *= 0.85;
      }
      _coinCooldown = interval;
    }

    if (!_sectionCompletionLocked && _sectionObjectivesMet) {
      _onSectionComplete();
    }
  }

  bool get _sectionObjectivesMet => SectionObjectives.isComplete(
    survivedSeconds: sectionSeconds,
    durationSeconds: currentSection.durationSeconds,
    coinsCollected: _sectionCoinCount,
    requiredCoins: currentSection.requiredCoins,
    travelDistance: _sectionTravel,
    minTravelDistance: currentSection.minTravelDistance,
  );

  void _updateProgress() {
    sectionProgress.value = SectionObjectives.progress(
      survivedSeconds: sectionSeconds,
      durationSeconds: currentSection.durationSeconds,
      coinsCollected: _sectionCoinCount,
      requiredCoins: currentSection.requiredCoins,
      travelDistance: _sectionTravel,
      minTravelDistance: currentSection.minTravelDistance,
    );
    final doneSections = sectionIndex.value;
    final sectionPart = sectionProgress.value;
    levelProgress.value = ((doneSections + sectionPart) / level.sectionCount)
        .clamp(0.0, 1.0);
  }

  int get _hazardCount => children.whereType<Obstacle>().length;
  int get _coinCount =>
      children.whereType<Coin>().where((c) => !c.collected).length;

  /// Spawns hazard patterns that cover the playable width — no permanent
  /// safe pocket under a standing player.
  void _trySpawnObstacleWave() {
    if (_hazardCount >= currentSection.maxHazards) return;

    final style = currentSection.mechanic == SectionMechanic.laneSweep
        ? HazardStyle.drifter
        : currentSection.hazardStyle;
    var speed = currentSection.fallSpeed;
    if (currentSection.mechanic == SectionMechanic.finaleStorm) {
      speed *= 1.1;
    }
    if (sectionSeconds > currentSection.durationSeconds) {
      speed *= 1.08;
    }

    final pattern = _spawnWave % 4;
    _spawnWave += 1;

    switch (pattern) {
      case 0:
        // Aimed near the player — forces movement.
        _spawnHazardAt(_aimedX(jitter: 36), style: style, speed: speed);
        break;
      case 1:
        // Dual side coverage.
        _spawnHazardAt(size.x * 0.22, style: style, speed: speed);
        _spawnHazardAt(size.x * 0.78, style: style, speed: speed * 0.98);
        break;
      case 2:
        // Center + flanking random.
        _spawnHazardAt(size.x * 0.5, style: style, speed: speed);
        _spawnHazardAt(
          _randomX(excludeCenter: false),
          style: style,
          speed: speed * 1.05,
        );
        break;
      default:
        // Full-width random + occasional player-lane pressure.
        _spawnHazardAt(_randomX(), style: style, speed: speed);
        if (level.number >= 3 || currentSection.index >= 1) {
          _spawnHazardAt(
            _aimedX(jitter: 70),
            style: style,
            speed: speed * 0.95,
          );
        }
        break;
    }
  }

  double _aimedX({required double jitter}) {
    final margin = 28.0;
    final x = player.position.x + (_random.nextDouble() * 2 - 1) * jitter;
    return x.clamp(margin, size.x - margin);
  }

  double _randomX({bool excludeCenter = false}) {
    final margin = 28.0;
    var x = margin + _random.nextDouble() * (size.x - margin * 2);
    if (excludeCenter && (x - size.x / 2).abs() < 40) {
      x = x < size.x / 2 ? size.x * 0.25 : size.x * 0.75;
    }
    return x;
  }

  void _spawnHazardAt(
    double x, {
    required HazardStyle style,
    required double speed,
  }) {
    if (_hazardCount >= currentSection.maxHazards) return;
    add(
      Obstacle(
        position: Vector2(x, -40 - _random.nextDouble() * 28),
        style: style,
        fallSpeed: speed,
      ),
    );
  }

  void _trySpawnCoin() {
    if (_coinCount >= currentSection.maxCoins) return;

    final margin = 28.0;
    final lane = _random.nextInt(5);
    final laneWidth = (size.x - margin * 2) / 5;
    var x = margin + lane * laneWidth + _random.nextDouble() * laneWidth;
    final y = Playfield.coinSpawnY;

    // Keep coins off the player's exact X so collecting requires movement.
    if ((x - player.position.x).abs() < 48) {
      x = (x + laneWidth * 2.2) % (size.x - margin * 2) + margin;
    }
    if (_isCrowdedNear(x, y, minDistance: 40)) {
      x = (x + laneWidth * 1.7) % (size.x - margin * 2) + margin;
    }

    add(
      Coin(position: Vector2(x, y), fallSpeed: currentSection.fallSpeed * 0.85),
    );
  }

  bool _isCrowdedNear(double x, double y, {required double minDistance}) {
    for (final o in children.whereType<Obstacle>()) {
      if ((o.position.x - x).abs() < minDistance &&
          (o.position.y - y).abs() < minDistance) {
        return true;
      }
    }
    for (final c in children.whereType<Coin>()) {
      if (c.collected) continue;
      if ((c.position.x - x).abs() < minDistance &&
          (c.position.y - y).abs() < minDistance) {
        return true;
      }
    }
    return false;
  }

  /// B04 helper — kill if still nested inside a hazard after shield ends.
  void _resolveStickyHazardOverlap() {
    const hitRadius = 36.0;
    for (final o in children.whereType<Obstacle>()) {
      if ((o.position - player.position).length <= hitRadius) {
        unawaited(onPlayerHit());
        return;
      }
    }
  }

  void onCoinCollected(Vector2 at) {
    // B09: credit coins even if death won the same collision step.
    if (phase.value != GamePhase.playing &&
        !(phase.value == GamePhase.gameOver && !_runCoinsBanked)) {
      return;
    }
    final mult = hasDoubleCoins ? 2 : 1;
    score.value = ScoringRules.combineScore(
      current: score.value,
      delta: ScoringRules.scoreForCoin() * mult,
    );
    runCoins.value += mult;
    _sectionCoinCount += 1;
    sectionCoins.value = _sectionCoinCount;
    player.pulseCollect();
    add(PickupBurst(position: at));
    if (mult > 1) {
      add(
        RewardBanner(
          label: '2x',
          accent: const Color(0xFFFFD76A),
          duration: 0.55,
          compact: true,
          position: Vector2(at.x, at.y - 28),
        ),
      );
    }
    audioService.playCoin();
    HapticFeedback.selectionClick();
    _updateProgress();
  }

  void onObstacleDodged() {
    if (phase.value != GamePhase.playing) return;
    score.value = ScoringRules.combineScore(
      current: score.value,
      delta: ScoringRules.scoreForDodge(),
    );
  }

  Future<void> _onSectionComplete() async {
    if (_sectionCompletionLocked || _levelCompletionLocked || _gameOverLocked) {
      return;
    }
    _sectionCompletionLocked = true;
    _roundActive = false;
    _keysDown.clear();
    _pendingSectionIntro = false;
    _sectionHandoffTick = 0;
    // Freeze immediately so late collisions cannot race the clear.
    _clearFieldEntities();

    final bonusCoins = currentSection.sectionBonusCoins;
    runCoins.value += bonusCoins;
    score.value = ScoringRules.combineScore(
      current: score.value,
      delta: bonusCoins * 2,
    );

    final nextIndex = currentSection.index + 1;
    if (nextIndex >= level.sections.length) {
      // B16: skip section-complete flash; go straight to level clear.
      await audioService.playClick();
      HapticFeedback.lightImpact();
      if (_gameOverLocked) return;
      await _onLevelComplete();
      return;
    }

    // Preview the upcoming section; handoff advances via update() dt.
    _applySection(level.sections[nextIndex]);
    phase.value = GamePhase.sectionComplete;
    _sectionHandoffTick = 0.35;
    _pendingSectionIntro = true;
    await audioService.playClick();
    HapticFeedback.lightImpact();
  }

  Future<void> _onLevelComplete() async {
    if (_levelCompletionLocked || _gameOverLocked) return;
    _levelCompletionLocked = true;
    _roundActive = false;
    _pendingSectionIntro = false;
    _sectionHandoffTick = 0;
    _keysDown.clear();
    _clearFieldEntities();
    // Keep prior phase until the final clear phase is assigned (avoids B16 flash).

    // Capture first-clear before persistence advances completed level.
    final alreadyCleared = level.number <= scoreService.highestCompletedLevel;

    lastRewardScore.value = level.completionScoreReward;
    score.value = ScoringRules.combineScore(
      current: score.value,
      delta: level.completionScoreReward,
    );

    // B01: mark banked so dispose/back cannot grant run coins twice.
    final runBanked = runCoins.value;
    if (!_runCoinsBanked && runBanked > 0) {
      await scoreService.addCoins(runBanked);
      _runCoinsBanked = true;
    }
    if (_gameOverLocked) return;

    var completionBonus = 0;
    if (!_challengeMode) {
      completionBonus = await scoreService.completeLevel(
        level.number,
        coinReward: level.completionCoinReward,
        score: score.value,
      );
    } else {
      // Arena: bank run coins only — no repeatable completion bonus.
      completionBonus = 0;
      await scoreService.submitScore(score.value);
    }
    if (_gameOverLocked) return;

    // B15: show total clear coins (run + first-clear bonus), not bonus alone.
    _clearDoublableCoins = runBanked + completionBonus;
    lastRewardCoins.value = _clearDoublableCoins;
    _clearDoubleClaimed = false;
    lastClearDoublableCoins.value = _clearDoublableCoins;
    clearDoubleClaimed.value = false;
    totalCoins.value = scoreService.totalCoins;
    bestScore.value = scoreService.bestScore;
    await audioService.playClick();
    HapticFeedback.mediumImpact();

    if (_challengeMode) {
      lastWorldRewardCoins.value = 0;
      phase.value = GamePhase.levelComplete;
    } else if (!alreadyCleared && level.number >= CampaignCatalog.maxLevel) {
      final worldIndex = CampaignProgress.worldIndexForLevel(level.number);
      final worldBonus = await scoreService.grantWorldReward(
        worldIndex,
        coinReward: CampaignProgress.worldCompletionReward(worldIndex),
      );
      lastWorldRewardCoins.value = worldBonus;
      lastWorldName.value = CampaignCatalog.themeForWorld(level.world).name;
      totalCoins.value = scoreService.totalCoins;
      phase.value = GamePhase.campaignComplete;
    } else if (!alreadyCleared &&
        CampaignProgress.isWorldFinaleLevel(level.number)) {
      final worldIndex = CampaignProgress.worldIndexForLevel(level.number);
      final worldBonus = await scoreService.grantWorldReward(
        worldIndex,
        coinReward: CampaignProgress.worldCompletionReward(worldIndex),
      );
      lastWorldRewardCoins.value = worldBonus;
      lastWorldName.value = CampaignCatalog.themeForWorld(level.world).name;
      totalCoins.value = scoreService.totalCoins;
      phase.value = GamePhase.worldComplete;
    } else {
      lastWorldRewardCoins.value = 0;
      phase.value = GamePhase.levelComplete;
    }
    pauseEngine();
  }

  /// Grants a matching second payout after a rewarded ad on the clear screen.
  Future<int> claimClearCoinDouble() async {
    if (_clearDoubleClaimed || _clearDoublableCoins <= 0) return 0;
    _clearDoubleClaimed = true;
    clearDoubleClaimed.value = true;
    await scoreService.addCoins(_clearDoublableCoins);
    // Total after double = 2 × clear payout.
    lastRewardCoins.value = _clearDoublableCoins * 2;
    totalCoins.value = scoreService.totalCoins;
    return _clearDoublableCoins;
  }

  Future<void> onPlayerHit() async {
    if (phase.value != GamePhase.playing ||
        _gameOverLocked ||
        _sectionCompletionLocked ||
        _levelCompletionLocked ||
        !_roundActive ||
        isInvulnerable) {
      return;
    }
    _gameOverLocked = true;
    _roundActive = false;
    _pendingSectionIntro = false;
    _keysDown.clear();
    phase.value = GamePhase.gameOver;

    player.flashHit();
    for (final o in children.whereType<Obstacle>()) {
      if ((o.position - player.position).length < 80) {
        o.playImpact();
      }
    }

    await audioService.stopMusic();
    await audioService.playGameOver();
    HapticFeedback.heavyImpact();

    // Defer coin banking so a rewarded continue does not double-grant.
    // Challenge scores must not overwrite campaign Level 50 bests.
    if (_challengeMode) {
      await scoreService.submitScore(score.value);
    } else {
      await scoreService.submitLevelScore(level.number, score.value);
    }
    bestScore.value = scoreService.bestScore;
    _gameOverSettle = 0.45;
  }

  void _clearTransientState() {
    _countdownTick = 0;
    _gameOverSettle = 0;
    _levelIntroTick = 0;
    _sectionIntroTick = 0;
    _sectionHandoffTick = 0;
    _pendingSectionIntro = false;
    _startingRound = false;
    _roundActive = false;
    _levelCompletionLocked = false;
    _sectionCompletionLocked = false;
    _gameOverLocked = false;
    _lifecycleSuspended = false;
    _keysDown.clear();
  }

  void disposeHostResources() {
    unawaited(_bankRunCoinsIfNeeded());
    _clearTransientState();
    // Stop (not pause) so the next screen can start BGM cleanly.
    audioService.stopMusic();
    try {
      pauseEngine();
    } catch (_) {}
  }

  @override
  void onRemove() {
    _clearTransientState();
    super.onRemove();
  }
}
