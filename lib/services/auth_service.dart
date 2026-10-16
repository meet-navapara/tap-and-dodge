import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';

/// Authentication lifecycle for Tap & Dodge.
enum AuthStatus { initializing, signedOut, guest, authenticated }

enum AuthProviderKind { google, apple }

/// Google / Apple SSO + local Guest sessions (separate from Flame).
class AuthService {
  AuthService({this._auth});

  FirebaseAuth? _auth;
  SharedPreferences? _prefs;
  bool firebaseReady = false;
  bool _googleSignInReady = false;

  static const _guestFlagKey = 'tap_dodge_auth_guest';
  static const _modeKey = 'tap_dodge_auth_mode';
  static const _guestIdKey = 'tap_dodge_guest_id';

  final ValueNotifier<AuthStatus> status = ValueNotifier(
    AuthStatus.initializing,
  );
  final ValueNotifier<User?> user = ValueNotifier(null);

  bool get isGuest => status.value == AuthStatus.guest;
  bool get isAuthenticated => status.value == AuthStatus.authenticated;
  bool get isGoogle =>
      isAuthenticated && providerKind == AuthProviderKind.google;
  bool get isApple => isAuthenticated && providerKind == AuthProviderKind.apple;
  bool get isSignedIn =>
      status.value == AuthStatus.guest ||
      status.value == AuthStatus.authenticated;
  bool get isSignedOut => status.value == AuthStatus.signedOut;
  String? get displayName => user.value?.displayName;
  String? get email => user.value?.email;
  String? get photoUrl => user.value?.photoURL;
  String? get uid => user.value?.uid;
  String? get guestId => _prefs?.getString(_guestIdKey);

  AuthProviderKind? get providerKind {
    final u = user.value;
    if (u == null) return null;
    for (final info in u.providerData) {
      if (info.providerId == 'google.com') return AuthProviderKind.google;
      if (info.providerId == 'apple.com') return AuthProviderKind.apple;
    }
    final mode = _prefs?.getString(_modeKey);
    if (mode == 'apple') return AuthProviderKind.apple;
    if (mode == 'google' || mode == 'authenticated') {
      return AuthProviderKind.google;
    }
    return null;
  }

  String get accountLabel {
    if (isGuest) return 'Guest';
    if (isApple) return displayName?.isNotEmpty == true ? displayName! : 'Apple';
    if (isGoogle) {
      return displayName?.isNotEmpty == true ? displayName! : 'Google';
    }
    return 'Account';
  }

  /// Fast local session restore (SharedPreferences). Call before [runApp].
  Future<void> initLocalSession() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs!.getString(_modeKey);
    if (saved == 'guest' || _prefs!.getBool(_guestFlagKey) == true) {
      status.value = AuthStatus.guest;
      user.value = null;
      return;
    }
    if (saved == 'google' ||
        saved == 'apple' ||
        saved == 'authenticated') {
      status.value = AuthStatus.authenticated;
      return;
    }
    status.value = AuthStatus.signedOut;
  }

  /// Firebase + Google Sign-In warm-up. Safe to call after UI is up.
  Future<void> initFirebase() async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 8));
      }
      _auth ??= FirebaseAuth.instance;
      firebaseReady = true;
    } catch (e, st) {
      debugPrint('Firebase init failed: $e\n$st');
      firebaseReady = false;
      if (status.value == AuthStatus.authenticated) {
        status.value = AuthStatus.signedOut;
      }
    }

    if (firebaseReady) {
      final current = _auth!.currentUser;
      if (current != null && !current.isAnonymous) {
        user.value = current;
        status.value = AuthStatus.authenticated;
        await _persistAuthenticatedMode();
        await _prefs!.setBool(_guestFlagKey, false);
      } else if (status.value == AuthStatus.authenticated) {
        status.value = AuthStatus.signedOut;
        await _prefs!.remove(_modeKey);
      }
    }

    unawaited(warmGoogleSignIn());
  }

  Future<void> _persistAuthenticatedMode() async {
    final kind = providerKind;
    if (kind == AuthProviderKind.apple) {
      await _prefs?.setString(_modeKey, 'apple');
    } else {
      await _prefs?.setString(_modeKey, 'google');
    }
  }

  /// Combined init used by tests / simple call sites.
  Future<void> init() async {
    await initLocalSession();
    await initFirebase();
  }

  Future<void> warmGoogleSignIn() async {
    if (!firebaseReady || _googleSignInReady) return;
    try {
      await _ensureGoogleSignIn();
    } catch (e, st) {
      debugPrint('Google Sign-In warm-up failed: $e\n$st');
    }
  }

  Future<void> _ensureGoogleSignIn() async {
    if (_googleSignInReady) return;
    final serverClientId = DefaultFirebaseOptions.googleServerClientId;
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _googleSignInReady = true;
  }

  Future<String> _ensureGuestId() async {
    _prefs ??= await SharedPreferences.getInstance();
    var id = _prefs!.getString(_guestIdKey);
    if (id == null || id.isEmpty) {
      final rng = Random.secure();
      final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
      id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _prefs!.setString(_guestIdKey, id);
    }
    return id;
  }

  /// Enter / resume guest mode. Does **not** wipe progress.
  Future<void> continueAsGuest() async {
    await _ensureGuestId();
    await _prefs?.setBool(_guestFlagKey, true);
    await _prefs?.setString(_modeKey, 'guest');
    if (firebaseReady) {
      try {
        await _auth?.signOut();
      } catch (_) {}
    }
    user.value = null;
    status.value = AuthStatus.guest;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!firebaseReady || _auth == null) {
      throw StateError(
        'Firebase is not ready yet. Check your connection and try again.',
      );
    }

    await _ensureGoogleSignIn();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google Sign-In did not return an ID token. '
        'Verify the Web client ID in firebase_options.dart.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth!.signInWithCredential(credential);

    await _prefs?.setBool(_guestFlagKey, false);
    await _prefs?.setString(_modeKey, 'google');
    user.value = result.user;
    status.value = AuthStatus.authenticated;
    return result;
  }

  /// Sign in with Apple — required on iOS App Store when offering Google SSO.
  Future<UserCredential> signInWithApple() async {
    if (!firebaseReady || _auth == null) {
      throw StateError(
        'Firebase is not ready yet. Check your connection and try again.',
      );
    }

    final rawNonce = _generateNonce();
    final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw StateError('Apple Sign-In did not return an identity token.');
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final result = await _auth!.signInWithCredential(oauthCredential);

    // Apple only sends the full name on the first authorization.
    final given = appleCredential.givenName;
    final family = appleCredential.familyName;
    if ((given != null || family != null) && result.user != null) {
      final fullName = [given, family].whereType<String>().join(' ').trim();
      if (fullName.isNotEmpty &&
          (result.user!.displayName == null ||
              result.user!.displayName!.isEmpty)) {
        await result.user!.updateDisplayName(fullName);
        await result.user!.reload();
        user.value = _auth!.currentUser;
      }
    }

    await _prefs?.setBool(_guestFlagKey, false);
    await _prefs?.setString(_modeKey, 'apple');
    user.value = _auth!.currentUser ?? result.user;
    status.value = AuthStatus.authenticated;
    return result;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Sign out. Does **not** delete Firestore cloud save.
  Future<void> signOut() async {
    if (firebaseReady) {
      try {
        if (_googleSignInReady) {
          await GoogleSignIn.instance.signOut();
        }
      } catch (_) {}
      try {
        await _auth?.signOut();
      } catch (_) {}
    }
    await _prefs?.setBool(_guestFlagKey, false);
    await _prefs?.remove(_modeKey);
    user.value = null;
    status.value = AuthStatus.signedOut;
  }

  Future<UserCredential> reauthenticateWithGoogle() async {
    if (!firebaseReady || _auth == null) {
      throw StateError('Firebase is not ready.');
    }
    await _ensureGoogleSignIn();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google Sign-In did not return an ID token.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final current = _auth!.currentUser;
    if (current == null) {
      return _auth!.signInWithCredential(credential);
    }
    return current.reauthenticateWithCredential(credential);
  }

  Future<UserCredential> reauthenticateWithApple() async {
    if (!firebaseReady || _auth == null) {
      throw StateError('Firebase is not ready.');
    }
    final rawNonce = _generateNonce();
    final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw StateError('Apple Sign-In did not return an identity token.');
    }
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );
    final current = _auth!.currentUser;
    if (current == null) {
      return _auth!.signInWithCredential(oauthCredential);
    }
    return current.reauthenticateWithCredential(oauthCredential);
  }

  /// Permanently deletes the Firebase Auth user. Call after cloud doc delete.
  Future<void> deleteFirebaseAuthUser() async {
    if (!firebaseReady || _auth == null) {
      throw StateError('Firebase is not ready.');
    }
    final current = _auth!.currentUser;
    if (current == null) {
      await signOut();
      return;
    }
    try {
      await current.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (providerKind == AuthProviderKind.apple) {
          await reauthenticateWithApple();
        } else {
          await reauthenticateWithGoogle();
        }
        await _auth!.currentUser?.delete();
      } else {
        rethrow;
      }
    }
    await _prefs?.setBool(_guestFlagKey, false);
    await _prefs?.remove(_modeKey);
    user.value = null;
    status.value = AuthStatus.signedOut;
    try {
      if (_googleSignInReady) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
  }

  /// Clears guest session id (explicit reset only).
  Future<void> clearGuestIdentity() async {
    await _prefs?.remove(_guestIdKey);
    await _prefs?.setBool(_guestFlagKey, false);
    await _prefs?.remove(_modeKey);
    if (status.value == AuthStatus.guest) {
      status.value = AuthStatus.signedOut;
    }
  }
}
