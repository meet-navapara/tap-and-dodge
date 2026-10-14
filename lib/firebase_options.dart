// Generated from Firebase project tapdodge-294f4 / google-services.json.
// Re-run `flutterfire configure` if you add platforms later.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web Firebase options not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS Firebase options not configured.');
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBkM3G4i_k9P100uOBb5VndCD0XtAYsSVU',
    appId: '1:474158228172:android:061bff8a748d9eb848d869',
    messagingSenderId: '474158228172',
    projectId: 'tapdodge-294f4',
    storageBucket: 'tapdodge-294f4.firebasestorage.app',
  );

  /// OAuth Web client ID (client_type 3) — required for Google → Firebase idToken.
  static const String googleServerClientId =
      '474158228172-thgdtuq6drhfun78s7ua29f1rb61qbi3.apps.googleusercontent.com';
}
