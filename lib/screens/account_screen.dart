import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

/// Profile / account settings: mode, sync, guest→Google, sign-out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
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
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  String? _message;

  SaveRepository get _repo => widget.sync.repository;

  Future<void> _saveGuestProgress() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.audioService.playClick();
      if (!widget.auth.firebaseReady) {
        await widget.auth.initFirebase();
      }
      final merged = await _repo.migrateGuestToGoogle();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _busy = false;
        _message =
            'Progress saved to Google. Unlocked level ${merged.unlockedLevel}, '
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
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.code == 'credential-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          _message =
              'That Google account is already linked elsewhere. '
              'Guest progress was not deleted. Sign in from the account screen '
              'with that Google account, or use another account.';
        } else {
          _message = e.message ?? 'Could not link Google. Guest progress kept.';
        }
      });
    } catch (e) {
      debugPrint('Guest migrate failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Could not save to Google. Your guest progress is still on this device.';
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
          'signs you out of this app. Your Google account itself is not '
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
    // Clear local progress to prevent account data leaking on a shared device.
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
    final isGoogle = auth.isAuthenticated;
    final name = auth.displayName ?? auth.email ?? 'Google player';

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
                    'Account',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AuthNeonPanel(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.panelBorder,
                      backgroundImage:
                          isGoogle && (auth.photoUrl?.isNotEmpty ?? false)
                          ? NetworkImage(auth.photoUrl!)
                          : null,
                      child: isGoogle && (auth.photoUrl?.isNotEmpty ?? false)
                          ? null
                          : Icon(
                              isGoogle
                                  ? Icons.person_rounded
                                  : Icons.sports_esports_rounded,
                              color: AppColors.player,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGoogle ? name : 'Guest',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isGoogle ? 'Cloud save enabled' : 'Local save only',
                            style: TextStyle(
                              color: AppColors.softWhite.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                          if (!isGoogle && auth.guestId != null) ...[
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 20),
              if (!isGoogle) ...[
                GoogleSignInButton(
                  busy: _busy,
                  label: 'Save My Progress',
                  onPressed: _saveGuestProgress,
                ),
                const SizedBox(height: 10),
                Text(
                  'Link Google to keep levels and coins if you change phones. '
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
                  'Required for Google Play when accounts exist. '
                  'Deletes only Tap & Dodge cloud data, not your Google login.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.softWhite.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _switchAccount,
                child: Text(
                  isGoogle
                      ? 'Use a different account'
                      : 'Back to account picker',
                  style: TextStyle(
                    color: AppColors.accent.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
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
