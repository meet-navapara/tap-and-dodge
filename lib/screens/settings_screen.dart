import 'package:firebase_auth/firebase_auth.dart';
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
import 'auth_gate_screen.dart';
import 'privacy_policy_screen.dart';

/// App settings: sound, privacy, and account / cloud save.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _muted = false;
  String? _message;

  SaveRepository get _repo => widget.sync.repository;

  bool get _showApple =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _muted = widget.audioService.isMuted;
  }

  Future<void> _toggleMute(bool muted) async {
    await widget.audioService.setMuted(muted);
    if (!mounted) return;
    setState(() => _muted = widget.audioService.isMuted);
    HapticFeedback.selectionClick();
    if (!_muted) {
      await widget.audioService.startMusic();
    }
  }

  Future<void> _openPrivacy() async {
    await widget.audioService.playClick();
    if (!mounted) return;
    if (LegalConfig.hasHostedPrivacyPolicy) {
      final uri = Uri.parse(LegalConfig.privacyPolicyUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  Future<void> _saveGuestProgress(AuthProviderKind provider) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final label = provider == AuthProviderKind.apple ? 'Apple' : 'Google';
    try {
      await widget.audioService.playClick();
      if (!widget.auth.firebaseReady) {
        await widget.auth.initFirebase();
      }
      final merged = await _repo.migrateGuestToAuthenticated(
        provider: provider,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _busy = false;
        _message =
            'Progress saved with $label. Unlocked level ${merged.unlockedLevel}, '
            '${merged.totalCoins} coins.';
      });
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.code == GoogleSignInExceptionCode.canceled) {
          _message = null;
        } else {
          _message = 'Google Sign-In failed. Guest progress is still safe.';
        }
      });
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.code == AuthorizationErrorCode.canceled) {
          _message = null;
        } else {
          _message = 'Apple Sign-In failed. Guest progress is still safe.';
        }
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.code == 'credential-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          _message =
              'That $label account is already linked elsewhere. '
              'Guest progress was not deleted.';
        } else {
          _message =
              e.message ?? 'Could not link $label. Guest progress kept.';
        }
      });
    } catch (e) {
      debugPrint('Guest migrate failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Could not save with $label. Your guest progress is still on this device.';
      });
    }
  }

  Future<void> _syncNow() async {
    if (_busy || !widget.auth.isAuthenticated) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await _repo.pushCloud();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok
          ? 'Cloud sync complete.'
          : 'Sync failed. Local progress is still safe — try again later.';
    });
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepNavy,
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your Tap & Dodge cloud save and '
          'signs you out of this app. Your Apple/Google account itself is not '
          'deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.obstacle),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _repo.deleteAccountAndData();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthGateScreen(
            scoreService: widget.scoreService,
            audioService: widget.audioService,
            connectivity: widget.connectivity,
            adMob: widget.adMob,
            auth: widget.auth,
            sync: widget.sync,
          ),
        ),
        (_) => false,
      );
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = e.code == GoogleSignInExceptionCode.canceled
            ? null
            : 'Account deletion needs a fresh Google confirmation. Try again.';
      });
    } catch (e) {
      debugPrint('Delete account failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Could not delete account. Check internet and try again. '
            'If it keeps failing, email ${LegalConfig.supportEmail.isEmpty ? 'support' : LegalConfig.supportEmail}.';
      });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepNavy,
        title: const Text('Sign out?'),
        content: const Text(
          'Your cloud save stays in your Google account. '
          'This device will clear the local copy so another player\'s data '
          'cannot mix in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repo.flushPush();
    } catch (_) {}
    await widget.auth.signOut();
    await widget.scoreService.clearAllProgress();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
          auth: widget.auth,
          sync: widget.sync,
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _resetGuest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepNavy,
        title: const Text('Reset guest progress?'),
        content: const Text(
          'This permanently deletes levels, coins, and skins on this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: AppColors.obstacle),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.scoreService.clearAllProgress();
    await widget.auth.clearGuestIdentity();
    await widget.auth.continueAsGuest();
    if (!mounted) return;
    setState(() {
      _message = 'Guest progress reset.';
    });
  }

  Future<void> _switchAccount() async {
    if (widget.auth.isAuthenticated) {
      await _signOut();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          scoreService: widget.scoreService,
          audioService: widget.audioService,
          connectivity: widget.connectivity,
          adMob: widget.adMob,
          auth: widget.auth,
          sync: widget.sync,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final isSignedInCloud = auth.isAuthenticated;
    final name = auth.accountLabel;

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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionLabel('Profile'),
              const SizedBox(height: 10),
              AuthNeonPanel(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.panelBorder,
                      backgroundImage:
                          isSignedInCloud &&
                              (auth.photoUrl?.isNotEmpty ?? false)
                          ? NetworkImage(auth.photoUrl!)
                          : null,
                      child:
                          isSignedInCloud &&
                              (auth.photoUrl?.isNotEmpty ?? false)
                          ? null
                          : Icon(
                              isSignedInCloud
                                  ? Icons.person_rounded
                                  : Icons.sports_esports_rounded,
                              color: AppColors.player,
                              size: 30,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSignedInCloud ? name : 'Guest',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSignedInCloud
                                ? 'Cloud save enabled'
                                : 'Local save only',
                            style: TextStyle(
                              color: AppColors.softWhite.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                          if (!isSignedInCloud && auth.guestId != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Guest ID · ${auth.guestId!.substring(0, 8)}…',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.softWhite.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<SyncState>(
                valueListenable: _repo.syncState,
                builder: (_, state, _) {
                  final label = switch (state) {
                    SyncState.idle => 'Ready',
                    SyncState.syncing => 'Syncing…',
                    SyncState.synced => 'Synced',
                    SyncState.offline => 'Offline',
                    SyncState.error => 'Sync error',
                  };
                  return Text(
                    'Sync status: $label',
                    style: TextStyle(
                      color: AppColors.softWhite.withValues(alpha: 0.6),
                    ),
                  );
                },
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                AuthNeonPanel(
                  child: Text(_message!, style: const TextStyle(height: 1.35)),
                ),
              ],
              const SizedBox(height: 16),
              if (!isSignedInCloud) ...[
                if (_showApple) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: SignInWithAppleButton(
                      onPressed: _busy
                          ? () {}
                          : () => _saveGuestProgress(AuthProviderKind.apple),
                      text: 'Save with Apple',
                      style: SignInWithAppleButtonStyle.white,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                GoogleSignInButton(
                  busy: _busy,
                  label: 'Save with Google',
                  onPressed: () =>
                      _saveGuestProgress(AuthProviderKind.google),
                ),
                const SizedBox(height: 10),
                Text(
                  'Link Apple or Google to keep levels and coins across devices. '
                  'We merge with any existing cloud save using the safer progress.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.softWhite.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _busy ? null : _resetGuest,
                  child: const Text('Reset guest progress'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _busy ? null : _syncNow,
                  child: Text(_busy ? 'Working…' : 'Sync Progress'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _signOut,
                  child: const Text('Sign Out'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _deleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.obstacle,
                    side: const BorderSide(color: AppColors.obstacle),
                  ),
                  child: const Text('Delete Account & Cloud Save'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Required by App Store / Play when accounts exist. '
                  'Deletes only Tap & Dodge cloud data, not your Apple/Google login.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.softWhite.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy ? null : _switchAccount,
                child: Text(
                  isSignedInCloud
                      ? 'Use a different account'
                      : 'Back to account picker',
                  style: TextStyle(
                    color: AppColors.accent.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Preferences'),
              const SizedBox(height: 10),
              _SettingsTile(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: !_muted,
                  onChanged: (on) => _toggleMute(!on),
                  secondary: Icon(
                    _muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: AppColors.player,
                  ),
                  title: const Text(
                    'Sound',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _muted ? 'Muted' : 'Music & effects on',
                    style: TextStyle(
                      color: AppColors.softWhite.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                  activeThumbColor: AppColors.accent,
                ),
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: _openPrivacy,
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.accent,
                  ),
                  title: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Ads, accounts & data',
                    style: TextStyle(
                      color: AppColors.softWhite.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.softWhite.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: AppColors.softWhite.withValues(alpha: 0.45),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: child,
    );
  }
}
