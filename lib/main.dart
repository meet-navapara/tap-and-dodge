import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/startup_gate_screen.dart';
import 'services/admob_service.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/progress_sync_service.dart';
import 'services/score_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final scoreService = ScoreService();
  final audioService = AudioService();
  final connectivity = ConnectivityService();
  final adMob = AdMobService(connectivity: connectivity);
  final auth = AuthService();
  final sync = ProgressSyncService(auth: auth, scoreService: scoreService);

  // Local-only work before first frame — Firebase warms on the splash.
  await scoreService.init();
  await audioService.init();
  await auth.initLocalSession();

  runApp(
    TapAndDodgeApp(
      scoreService: scoreService,
      audioService: audioService,
      connectivity: connectivity,
      adMob: adMob,
      auth: auth,
      sync: sync,
    ),
  );
}

class TapAndDodgeApp extends StatelessWidget {
  const TapAndDodgeApp({
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
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tap & Dodge',
      theme: AppTheme.dark(),
      home: StartupGateScreen(
        scoreService: scoreService,
        audioService: audioService,
        connectivity: connectivity,
        adMob: adMob,
        auth: auth,
        sync: sync,
      ),
    );
  }
}
