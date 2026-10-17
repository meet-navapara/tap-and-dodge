import 'dart:async';

import 'package:flutter/material.dart';

import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/progress_sync_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate_screen.dart';
import 'home_screen.dart';

/// Fast splash → auth/home. Ads & Firebase warm in parallel.
class StartupGateScreen extends StatefulWidget {
  const StartupGateScreen({
    super.key,
    required this.scoreService,
    required this.audioService,
    required this.connectivity,
    required this.adMob,
    required this.auth,
    required this.sync,
  });

  final ScoreService scoreService;
  final AudioService audioService;
  final ConnectivityService connectivity;
  final AdMobService adMob;
  final AuthService auth;
  final ProgressSyncService sync;

  @override
  State<StartupGateScreen> createState() => _StartupGateScreenState();
}

class _StartupGateScreenState extends State<StartupGateScreen> {
  bool _ready = false;
  bool _offlineAuth = false;
  String _status = 'Starting Tap & Dodge…';

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() => _status = 'Checking connection…');
    await widget.connectivity.start();
    // Don't fake "online" on probe timeout — Guest still works offline.
    final online = await widget.connectivity
        .refresh(forceProbe: true)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => widget.connectivity.hasInternet.value,
        );

    setState(() => _status = 'Preparing…');
    await widget.auth.initFirebase().timeout(
      const Duration(seconds: 6),
      onTimeout: () {},
    );

    if (!mounted) return;

    debugPrint('Startup: warming AdMob (online=$online)…');
    final adsInit = _initAdsOnly();

    // Cloud restore before Home so pushes don't overwrite better cloud data.
    if (online && widget.auth.isAuthenticated) {
      setState(() => _status = 'Restoring cloud save…');
      await widget.sync.restoreIfGoogle().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Cloud restore timed out — pushes stay blocked');
          return false;
        },
      );
    }

    // Finish ads init, then show app-open ONLY while splash is still up.
    setState(() => _status = 'Almost ready…');
    await adsInit.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('AdMob init still running in background…');
      },
    );

    if (mounted && !_ready) {
      await widget.adMob.showStartupAppOpenIfEligible().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
    }

    if (!mounted) return;
    setState(() {
      _offlineAuth = !online;
      _ready = true;
    });
  }

  Future<void> _initAdsOnly() async {
    try {
      await widget.adMob.initialize();
    } catch (e, st) {
      debugPrint('AdMob init failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      if (widget.auth.isSignedIn) {
        // Signed-in users can open Home offline; ads/campaign still gate online.
        return HomeScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
          auth: widget.auth,
          sync: widget.sync,
        );
      }
      return AuthGateScreen(
        scoreService: widget.scoreService,
        audioService: widget.audioService,
        connectivity: widget.connectivity,
        adMob: widget.adMob,
        auth: widget.auth,
        sync: widget.sync,
        offline: _offlineAuth,
      );
    }

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
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TAP & DODGE',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.player,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _status,
                  style: TextStyle(
                    color: AppColors.softWhite.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.accent,
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
