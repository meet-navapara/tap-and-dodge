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

  Timer? _debounce;
  bool _writeInFlight = false;
  bool _writeQueued = false;

  DocumentReference<Map<String, dynamic>>? _userDoc(String uid) {
    final db = _firestore ?? FirebaseFirestore.instance;
    return db.collection('users').doc(uid);
  }

  PlayerProgress exportLocal() => scoreService.exportProgress();

  Future<void> importLocal(PlayerProgress data) =>
      scoreService.importProgress(data);

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

  Future<bool> pushCloud({
    PlayerProgress? progress,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!auth.firebaseReady || !auth.isAuthenticated) return false;
    final uid = auth.uid;
    if (uid == null) return false;
    if (_writeInFlight) {
      _writeQueued = true;
      return false;
    }
    _writeInFlight = true;
    try {
      syncState.value = SyncState.syncing;
      final payload = progress ?? exportLocal();
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
    } finally {
      _writeInFlight = false;
      if (_writeQueued) {
        _writeQueued = false;
        unawaited(pushCloud());
      }
    }
  }

  /// Debounced push after gameplay checkpoints.
  void schedulePush({Duration delay = const Duration(seconds: 2)}) {
    if (!auth.isAuthenticated) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      unawaited(pushCloud());
    });
  }

  Future<void> flushPush() async {
    _debounce?.cancel();
    await pushCloud();
  }

  /// Restore Google cloud into local. If cloud missing, upload local defaults.
  /// On network failure: keep local intact (never overwrite with empty).
  Future<bool> restoreAuthenticatedSession() async {
    if (!auth.isAuthenticated) return false;
    final cloud = await fetchCloud();
    if (cloud != null) {
      await importLocal(cloud);
      return true;
    }
    if (syncState.value == SyncState.error) {
      // Keep local; do not push empty defaults over a possibly existing cloud.
      return false;
    }
    await pushCloud();
    return false;
  }

  /// Guest → Google: preserve guest progress, merge with cloud, write both.
  Future<PlayerProgress> migrateGuestToGoogle() async {
    final local = exportLocal();
    await auth.signInWithGoogle();
    final cloud = await fetchCloud();
    final merged = ProgressMerge.merge(local, cloud);
    await importLocal(merged);
    await pushCloud(progress: merged);
    return merged;
  }

  /// Play Store account-deletion: erase cloud save + Firebase Auth user + local.
  Future<void> deleteAccountAndData() async {
    if (!auth.isAuthenticated) {
      throw StateError('No Google account is signed in.');
    }
    final uid = auth.uid;
    if (uid == null) {
      throw StateError('Missing user id.');
    }
    syncState.value = SyncState.syncing;
    try {
      try {
        await _userDoc(uid)!.delete().timeout(const Duration(seconds: 12));
      } catch (e, st) {
        // Continue with Auth delete even if doc already missing.
        debugPrint('Cloud delete (may already be gone): $e\n$st');
      }
      await auth.deleteFirebaseAuthUser();
      await scoreService.clearAllProgress();
      syncState.value = SyncState.idle;
    } catch (e, st) {
      debugPrint('Account deletion failed: $e\n$st');
      lastError = '$e';
      syncState.value = SyncState.error;
      rethrow;
    }
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
