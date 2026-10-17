import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/legal_config.dart';
import '../services/progress_sync_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';
import '../widgets/google_sign_in_button.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';

/// Premium account picker — Google (cloud) or Guest (local).
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({
    super.key,
    required this.scoreService,
    required this.audioService,
    required this.connectivity,
    required this.adMob,
    required this.auth,
    required this.sync,
    this.offline = false,
  });

  final ScoreService scoreService;
  final AudioService audioService;
  final ConnectivityService connectivity;
  final AdMobService adMob;
  final AuthService auth;
  final ProgressSyncService sync;
  final bool offline;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _busyGoogle = false;
  bool _busyApple = false;
  bool _busyGuest = false;
  String? _error;
  bool _offline = false;

  bool get _showApple =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    // Guest / Google picker can appear before startup ad warm finishes.
    unawaited(widget.adMob.ensureInitialized());
    _offline = widget.offline || !widget.connectivity.hasInternet.value;
    widget.connectivity.hasInternet.addListener(_onConnectivity);
  }

  @override
  void dispose() {
    widget.connectivity.hasInternet.removeListener(_onConnectivity);
    super.dispose();
  }

  void _onConnectivity() {
    if (!mounted) return;
    setState(() => _offline = !widget.connectivity.hasInternet.value);
  }

  bool get _busy => _busyGoogle || _busyApple || _busyGuest;

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => HomeScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
          auth: widget.auth,
          sync: widget.sync,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  Future<void> _continueGuest() async {
    if (_busy) return;
    setState(() {
      _busyGuest = true;
      _error = null;
    });
    try {
      await widget.audioService.playClick();
      // Resume guest — never wipe progress here (explicit reset is in Account).
      await widget.auth.continueAsGuest();
      HapticFeedback.mediumImpact();
      await _goHome();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busyGuest = false;
        _error = 'Could not start guest mode. Try again.';
      });
    }
  }

  Future<void> _afterCloudAuth() async {
    final repo = widget.sync.repository;
    final local = repo.exportLocal();
    // Always merge when local guest progress exists — never blind-restore.
    if (SaveRepository.hasMeaningfulProgress(local)) {
      await repo.mergeLocalWithCloudAfterSignIn();
    } else {
      final restored = await widget.sync.restoreIfGoogle();
      if (!restored && repo.syncState.value != SyncState.error) {
        await widget.sync.pushIfGoogle();
      }
    }
    HapticFeedback.mediumImpact();
    await _goHome();
  }

  Future<void> _ensureFirebase() async {
    if (!widget.auth.firebaseReady) {
      await widget.auth.initFirebase().timeout(const Duration(seconds: 8));
    }
    if (!widget.auth.firebaseReady) {
      throw StateError(
        'Firebase is still starting. Please retry in a moment.',
      );
    }
  }

  Future<void> _signInGoogle() async {
    if (_busy) return;
    if (_offline) {
      setState(() {
        _error = 'Internet required for sign-in. Play as Guest offline.';
      });
      return;
    }
    setState(() {
      _busyGoogle = true;
      _error = null;
    });
    try {
      await widget.audioService.playClick();
      await _ensureFirebase();
      await widget.auth.signInWithGoogle();
      await _afterCloudAuth();
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in cancelled/failed: $e');
      if (!mounted) return;
      setState(() {
        _busyGoogle = false;
        if (e.code == GoogleSignInExceptionCode.canceled ||
            e.code == GoogleSignInExceptionCode.interrupted) {
          _error = null;
        } else {
          _error = 'Google Sign-In failed. Tap to retry.';
        }
      });
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      setState(() {
        _busyGoogle = false;
        _error = e is StateError
            ? e.message
            : 'Google Sign-In failed. Check internet and retry.';
      });
    }
  }

  Future<void> _signInApple() async {
    if (_busy) return;
    if (_offline) {
      setState(() {
        _error = 'Internet required for sign-in. Play as Guest offline.';
      });
      return;
    }
    setState(() {
      _busyApple = true;
      _error = null;
    });
    try {
      await widget.audioService.playClick();
      await _ensureFirebase();
      await widget.auth.signInWithApple();
      await _afterCloudAuth();
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('Apple sign-in cancelled/failed: $e');
      if (!mounted) return;
      setState(() {
        _busyApple = false;
        if (e.code == AuthorizationErrorCode.canceled) {
          _error = null;
        } else {
          _error = 'Apple Sign-In failed. Tap to retry.';
        }
      });
    } catch (e) {
      debugPrint('Apple sign-in failed: $e');
      if (!mounted) return;
      setState(() {
        _busyApple = false;
        _error = e is StateError
            ? e.message
            : 'Apple Sign-In failed. Check internet and retry.';
      });
    }
  }

  Future<void> _openPrivacy() async {
    if (LegalConfig.hasHostedPrivacyPolicy) {
      final uri = Uri.parse(LegalConfig.privacyPolicyUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  Future<void> _openTerms() async {
    if (!LegalConfig.hasHostedTerms) {
      await _openPrivacy();
      return;
    }
    final uri = Uri.parse(LegalConfig.termsOfServiceUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF142057), AppColors.deepNavy, AppColors.midnight],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _openPrivacy,
                    child: Text(
                      'Privacy',
                      style: TextStyle(
                        color: AppColors.softWhite.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _HeroArtwork(),
                const SizedBox(height: 22),
                const Text(
                  'TAP & DODGE',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    color: AppColors.player,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to Dodge?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.softWhite.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Save with Google to keep levels across devices,\n'
                  'or play as Guest on this phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.softWhite.withValues(alpha: 0.65),
                    height: 1.35,
                  ),
                ),
                if (_offline) ...[
                  const SizedBox(height: 14),
                  AuthNeonPanel(
                    child: Text(
                      'You\'re offline. Guest still works. '
                      'Google Sign-In needs internet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.accent.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.obstacle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(flex: 3),
                if (_showApple) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: _busyApple
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          )
                        : SignInWithAppleButton(
                            onPressed: (_busy || _offline) ? null : _signInApple,
                            style: SignInWithAppleButtonStyle.white,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(16),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                GoogleSignInButton(
                  busy: _busyGoogle,
                  enabled: !_busyGuest && !_busyApple && !_offline,
                  onPressed: _signInGoogle,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _continueGuest,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.player,
                        width: 1.4,
                      ),
                      foregroundColor: AppColors.player,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _busyGuest
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Text(
                            'Play as Guest',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Guest progress stays on this device and can be lost if you '
                  'uninstall or clear app data. Connect Apple or Google anytime '
                  'from Account to save permanently.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.softWhite.withValues(alpha: 0.45),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _openPrivacy,
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.softWhite.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    if (LegalConfig.hasHostedTerms) ...[
                      Text(
                        '·',
                        style: TextStyle(
                          color: AppColors.softWhite.withValues(alpha: 0.35),
                        ),
                      ),
                      TextButton(
                        onPressed: _openTerms,
                        child: Text(
                          'Terms',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.softWhite.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.player.withValues(alpha: 0.28),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9EFFFF),
                  AppColors.player,
                  AppColors.playerDeep,
                  AppColors.violet,
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x6639F3FF),
                  blurRadius: 32,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 56,
              color: Color(0xFF070B1A),
            ),
          ),
          Positioned(
            left: 36,
            top: 28,
            child: _Orb(
              color: AppColors.coin.withValues(alpha: 0.85),
              size: 14,
            ),
          ),
          Positioned(
            right: 40,
            bottom: 30,
            child: _Orb(
              color: AppColors.obstacle.withValues(alpha: 0.8),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 10)],
      ),
    );
  }
}
