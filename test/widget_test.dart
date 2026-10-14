import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_and_dodge/screens/home_screen.dart';
import 'package:tap_and_dodge/services/admob_service.dart';
import 'package:tap_and_dodge/services/audio_service.dart';
import 'package:tap_and_dodge/services/connectivity_service.dart';
import 'package:tap_and_dodge/services/score_service.dart';
import 'package:tap_and_dodge/theme/app_theme.dart';

/// Test double that never touches platform audio plugins.
class _SilentAudioService extends AudioService {
  @override
  Future<void> init() async {}

  @override
  bool get isMuted => false;

  @override
  Future<void> startMusic() async {}

  @override
  Future<void> toggleMute() async {}

  @override
  Future<void> playClick() async {}
}

class _FakeConnectivity extends ConnectivityService {
  _FakeConnectivity() : super();

  @override
  Future<void> start() async {
    hasInternet.value = true;
  }

  @override
  Future<bool> refresh({bool forceProbe = false}) async {
    hasInternet.value = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home screen shows title and play button', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final scoreService = ScoreService();
    await scoreService.init();
    final connectivity = _FakeConnectivity();
    await connectivity.start();
    final adMob = AdMobService(connectivity: connectivity);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: HomeScreen(
          scoreService: scoreService,
          audioService: _SilentAudioService(),
          connectivity: connectivity,
          adMob: adMob,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('TAP & DODGE'), findsOneWidget);
    expect(find.text('PLAY CAMPAIGN'), findsOneWidget);
    expect(find.text('HANGAR'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.textContaining('Best'), findsOneWidget);
    expect(find.textContaining('Coins'), findsOneWidget);
  });
}
