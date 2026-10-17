import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/progress_sync_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate_screen.dart';
import 'connection_required_screen.dart';
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
  bool _needsInternet = false;
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
    final online = await widget.connectivity
        .refresh(forceProbe: true)
        .timeout(const Duration(seconds: 3), onTimeout: () => true);

    setState(() => _status = 'Preparing…');
    // Firebase + Google warm-up — do not block auth UI for long.
    await widget.auth.initFirebase().timeout(
      const Duration(seconds: 6),
      onTimeout: () {},
    );

    if (!mounted) return;

    // Always start AdMob (show paths still require connectivity).
    debugPrint('Startup: warming AdMob (online=$online)…');
    unawaited(_warmAdsInBackground());

    if (!online) {
      // Auth itself can continue for Guest; gameplay still needs internet later.
      if (widget.auth.isSignedIn) {
        setState(() {
          _needsInternet = true;
          _ready = false;
        });
        return;
      }
      setState(() {
        _offlineAuth = true;
        _needsInternet = false;
        _ready = true;
      });
      return;
    }

    // Cloud restore after UI decision — only for returning Google users,
    // with a short timeout so splash stays snappy.
    if (widget.auth.isAuthenticated) {
      setState(() => _status = 'Restoring cloud save…');
      await widget.sync.restoreIfGoogle().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    }

    if (!mounted) return;
    setState(() {
      _needsInternet = false;
      _offlineAuth = false;
      _ready = true;
    });
  }

  Future<void> _warmAdsInBackground() async {
    try {
      if (kIsWeb) {
        await widget.adMob.initialize();
        return;
      }
      // Give Mobile Ads + UMP enough time; show/load paths also call
      // ensureInitialized() so a timeout here is not fatal.
      await widget.adMob.initialize().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('AdMob init still running in background…');
        },
      );
      // Let rewarded preload claim WebView first; app-open can wait.
      await Future<void>.delayed(const Duration(seconds: 5));
      await widget.adMob.showStartupAppOpenIfEligible().timeout(
        const Duration(seconds: 12),
        onTimeout: () => false,
      );
    } catch (e, st) {
      debugPrint('Background ad warm-up failed: $e\n$st');
    }
  }

  Future<void> _retry() async {
    setState(() {
      _needsInternet = false;
      _status = 'Retrying…';
    });
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsInternet) {
      return ConnectionRequiredScreen(onRetry: _retry);
    }
    if (_ready) {
      if (widget.auth.isSignedIn) {
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
