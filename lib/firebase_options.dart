// Firebase options for Android + iOS (project tapdodge-294f4).
// After adding the iOS app in Firebase Console, run:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=tapdodge-294f4 --platforms=android,ios
// Or paste values from GoogleService-Info.plist into [ios] below.

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
        return ios;
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

  /// From GoogleService-Info.plist (iOS app com.ujjwal.tapandodge).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCF_x64_D2_6A2gKbDe0-hxTuaF2Hwwj7s',
    appId: '1:474158228172:ios:fd157448b34a6e0f48d869',
    messagingSenderId: '474158228172',
    projectId: 'tapdodge-294f4',
    storageBucket: 'tapdodge-294f4.firebasestorage.app',
    iosBundleId: 'com.ujjwal.tapandodge',
  );

  /// OAuth **Web** client ID — used as Google Sign-In serverClientId on
  /// Android and iOS so Firebase Auth receives an idToken.
  static const String googleServerClientId =
      '474158228172-thgdtuq6drhfun78s7ua29f1rb61qbi3.apps.googleusercontent.com';
}
