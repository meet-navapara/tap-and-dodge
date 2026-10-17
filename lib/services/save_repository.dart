import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'player_progress.dart';
import 'progress_merge.dart';
import 'score_service.dart';

enum SyncState { idle, syncing, synced, offline, error }

/// Local + Firestore save layer with debounced cloud writes.
class SaveRepository {
  SaveRepository({
    required this.auth,
    required this.scoreService,
    this._firestore,
  });

  final AuthService auth;
  final ScoreService scoreService;
  final FirebaseFirestore? _firestore;

  final ValueNotifier<SyncState> syncState = ValueNotifier(SyncState.idle);
  String? lastError;

  /// When false, gameplay must not push local over unknown cloud state.
  bool _sessionHydrated = false;

  Timer? _debounce;
  bool _writeQueued = false;
  Future<bool>? _activeDrain;

  bool get isSessionHydrated => _sessionHydrated;

  DocumentReference<Map<String, dynamic>>? _userDoc(String uid) {
    final db = _firestore ?? FirebaseFirestore.instance;
    return db.collection('users').doc(uid);
  }

  PlayerProgress exportLocal() => scoreService.exportProgress();

  Future<void> importLocal(PlayerProgress data) =>
      scoreService.importProgress(data);

  static bool hasMeaningfulProgress(PlayerProgress p) {
    return p.unlockedLevel > 1 ||
        p.highestCompletedLevel > 0 ||
        p.totalCoins > 0 ||
        p.bestScore > 0 ||
        p.ownedSkinIds.length > 1;
  }

  /// Fetch cloud save. Returns null if missing / unavailable (does not wipe local).
  Future<PlayerProgress?> fetchCloud({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!auth.firebaseReady || !auth.isAuthenticated) return null;
    final uid = auth.uid;
    if (uid == null) return null;
    try {
      syncState.value = SyncState.syncing;
      final snap = await _userDoc(uid)!.get().timeout(timeout);
      if (!snap.exists || snap.data() == null) {
        syncState.value = SyncState.idle;
        return null;
      }
      final data = snap.data()!;
      final progressMap = data['progress'];
      final progress = PlayerProgress.fromMap(
        progressMap is Map<String, dynamic>
            ? progressMap
            : Map<String, dynamic>.from(progressMap as Map? ?? {}),
      );
      syncState.value = SyncState.synced;
      return progress;
    } catch (e, st) {
      debugPrint('Cloud fetch failed: $e\n$st');
      lastError = '$e';
      syncState.value = SyncState.error;
      return null;
    }
  }

  Future<bool> _writeOnce(
    PlayerProgress payload, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uid = auth.uid;
    if (uid == null) return false;
    try {
      syncState.value = SyncState.syncing;
      await _userDoc(uid)!
          .set({
            'uid': uid,
            'email': auth.email,
            'displayName': auth.displayName,
            'schemaVersion': PlayerProgress.currentSchemaVersion,
            'progress': payload.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(timeout);
      syncState.value = SyncState.synced;
      return true;
    } catch (e, st) {
      debugPrint('Cloud push failed: $e\n$st');
      lastError = '$e';
      syncState.value = SyncState.error;
      return false;
    }
  }

  /// Push local (or [progress]) to cloud.
  ///
  /// Concurrent callers await the same drain; each drain cycle re-exports
  /// fresh local progress so intermediate saves are not dropped.
  Future<bool> pushCloud({
    PlayerProgress? progress,
    Duration timeout = const Duration(seconds: 8),
    bool allowUnhydrated = false,
  }) async {
    if (!auth.firebaseReady || !auth.isAuthenticated) return false;
    if (auth.uid == null) return false;
    if (!_sessionHydrated && !allowUnhydrated && progress == null) {
      debugPrint('Cloud push skipped — session not hydrated yet');
      return false;
    }

    _writeQueued = true;
    if (_activeDrain != null) {
      return _activeDrain!;
    }

    _activeDrain = () async {
      var lastOk = false;
      try {
        PlayerProgress? explicit = progress;
        do {
          _writeQueued = false;
          final payload = explicit ?? exportLocal();
          explicit = null;
          lastOk = await _writeOnce(payload, timeout: timeout);
        } while (_writeQueued);
      } finally {
        _activeDrain = null;
      }
      return lastOk;
    }();

    return _activeDrain!;
  }

  /// Debounced push after gameplay checkpoints.
  void schedulePush({Duration delay = const Duration(seconds: 2)}) {
    if (!auth.isAuthenticated || !_sessionHydrated) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      unawaited(pushCloud());
    });
  }

  Future<void> flushPush() async {
    _debounce?.cancel();
    await pushCloud();
  }

  /// Merge cloud into local (never blind-overwrite). Upload merged result.
  /// On network failure: keep local intact and leave session unhydrated so
  /// pushes stay blocked until a successful restore.
  Future<bool> restoreAuthenticatedSession() async {
    if (!auth.isAuthenticated) return false;
    final local = exportLocal();
    final cloud = await fetchCloud();
    if (cloud != null) {
      final merged = ProgressMerge.merge(local, cloud);
      await importLocal(merged);
      final ok = await pushCloud(progress: merged, allowUnhydrated: true);
      _sessionHydrated = ok || syncState.value != SyncState.error;
      if (!_sessionHydrated) {
        // Merge applied locally; still allow pushes of merged state.
        _sessionHydrated = true;
      }
      return true;
    }
    if (syncState.value == SyncState.error) {
      // Keep local; do not push empty defaults over a possibly existing cloud.
      _sessionHydrated = false;
      return false;
    }
    // No cloud doc — seed with local.
    final ok = await pushCloud(progress: local, allowUnhydrated: true);
    _sessionHydrated = true;
    return ok;
  }

  /// After AuthGate Google/Apple sign-in: merge any local guest progress.
  Future<PlayerProgress> mergeLocalWithCloudAfterSignIn() async {
    final local = exportLocal();
    final cloud = await fetchCloud();
    if (syncState.value == SyncState.error && cloud == null) {
      _sessionHydrated = false;
      return local;
    }
    final merged = ProgressMerge.merge(local, cloud);
    await importLocal(merged);
    await pushCloud(progress: merged, allowUnhydrated: true);
    _sessionHydrated = true;
    return merged;
  }

  /// Guest → Google/Apple: preserve guest progress, merge with cloud, write both.
  Future<PlayerProgress> migrateGuestToAuthenticated({
    AuthProviderKind provider = AuthProviderKind.google,
  }) async {
    final local = exportLocal();
    if (provider == AuthProviderKind.apple) {
      await auth.signInWithApple();
    } else {
      await auth.signInWithGoogle();
    }
    final cloud = await fetchCloud();
    final merged = ProgressMerge.merge(local, cloud);
    await importLocal(merged);
    await pushCloud(progress: merged, allowUnhydrated: true);
    _sessionHydrated = true;
    return merged;
  }

  /// Backward-compatible alias.
  Future<PlayerProgress> migrateGuestToGoogle() =>
      migrateGuestToAuthenticated(provider: AuthProviderKind.google);

  /// Play Store account-deletion: re-auth → erase cloud → Auth user → local.
  Future<void> deleteAccountAndData() async {
    if (!auth.isAuthenticated) {
      throw StateError('No signed-in account.');
    }
    final uid = auth.uid;
    if (uid == null) {
      throw StateError('Missing user id.');
    }
    syncState.value = SyncState.syncing;
    try {
      // Re-auth FIRST so we never delete cloud then fail Auth.
      await auth.reauthenticateForSensitiveAction();

      try {
        await _userDoc(uid)!.delete().timeout(const Duration(seconds: 12));
      } catch (e, st) {
        debugPrint('Cloud delete (may already be gone): $e\n$st');
      }

      await auth.deleteFirebaseAuthUser();
      await scoreService.clearAllProgress();
      _sessionHydrated = false;
      syncState.value = SyncState.idle;
    } catch (e, st) {
      debugPrint('Account deletion failed: $e\n$st');
      lastError = '$e';
      syncState.value = SyncState.error;
      rethrow;
    }
  }

  void markSignedOut() {
    _sessionHydrated = false;
  }

  void dispose() {
    _debounce?.cancel();
  }
}

/// Backward-compatible façade used by existing call sites.
class ProgressSyncService {
  ProgressSyncService({
    required AuthService auth,
    required ScoreService scoreService,
    FirebaseFirestore? firestore,
  }) : repository = SaveRepository(
         auth: auth,
         scoreService: scoreService,
         firestore: firestore,
       );

  final SaveRepository repository;

  Future<bool> restoreIfGoogle() => repository.restoreAuthenticatedSession();

  Future<void> pushIfGoogle() async {
    await repository.pushCloud();
  }

  void schedulePush() => repository.schedulePush();
}
