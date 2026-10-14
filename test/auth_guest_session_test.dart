import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_and_dodge/services/auth_service.dart';
import 'package:tap_and_dodge/services/score_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'guest session restores on local init without wiping progress',
    () async {
      SharedPreferences.setMockInitialValues({
        'tap_dodge_auth_mode': 'guest',
        'tap_dodge_auth_guest': true,
        'tap_dodge_guest_id': 'abc123guest',
        'tap_dodge_unlocked_level_v2': 9,
        'tap_dodge_total_coins': 77,
      });

      final auth = AuthService();
      await auth.initLocalSession();
      expect(auth.status.value, AuthStatus.guest);
      expect(auth.isSignedIn, isTrue);

      final scores = ScoreService();
      await scores.init();
      expect(scores.unlockedLevel, 9);
      expect(scores.totalCoins, 77);

      // continueAsGuest must not wipe.
      await auth.continueAsGuest();
      expect(scores.unlockedLevel, 9);
      expect(auth.guestId, 'abc123guest');
    },
  );

  test('signed-out local session does not auto-enter guest', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.initLocalSession();
    expect(auth.status.value, AuthStatus.signedOut);
    expect(auth.isSignedIn, isFalse);
  });

  test('clearAllProgress keeps auth keys for guest resume', () async {
    SharedPreferences.setMockInitialValues({
      'tap_dodge_auth_mode': 'guest',
      'tap_dodge_auth_guest': true,
      'tap_dodge_total_coins': 40,
    });
    final scores = ScoreService();
    await scores.init();
    await scores.clearAllProgress();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tap_dodge_auth_mode'), 'guest');
    expect(scores.totalCoins, 0);
  });
}
