import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/legal_config.dart';
import '../theme/app_theme.dart';

/// In-app privacy policy (required when shipping with ads).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openHosted() async {
    if (!LegalConfig.hasHostedPrivacyPolicy) return;
    final uri = Uri.parse(LegalConfig.privacyPolicyUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: AppColors.softWhite.withValues(alpha: 0.85),
                      height: 1.45,
                      fontSize: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LegalConfig.appName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.player,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This game can store progress (high score, coins, unlocks, '
                          'daily streak, and cosmetic unlocks) locally on your device '
                          'using on-device preferences. If you sign in with Google, '
                          'the same progress may also be saved to Firebase so you can '
                          'restore it on another device. Guest mode keeps data only '
                          'on this device and may be lost if you uninstall or clear app data.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Internet access is required to play because the game shows '
                          'advertisements (rewarded, interstitial, and app-open) through '
                          'Google AdMob. Ad networks may collect advertising identifiers '
                          'and device/network information to serve and measure ads, '
                          'subject to your consent choices where required by law.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'In the European Economic Area, UK, and similar regions, '
                          'we present Google\'s consent message (UMP) before requesting '
                          'ads when required. You can change device ad preferences in '
                          'your system settings.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'We do not sell your personal information. Crash or analytics '
                          'tools are not bundled in this build unless listed in a future '
                          'update of this policy.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Children: This game is a casual arcade title. If you are a '
                          'parent/guardian, supervise play and device ad settings. '
                          'If you publish for under-13 audiences, configure AdMob '
                          'and Play policies for families accordingly.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Contact: ${LegalConfig.supportEmail.isEmpty ? 'add your support email in LegalConfig before publishing' : LegalConfig.supportEmail}',
                        ),
                        const SizedBox(height: 20),
                        if (LegalConfig.hasHostedPrivacyPolicy)
                          ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _openHosted();
                            },
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open hosted policy'),
                          )
                        else
                          Text(
                            'Tip: set LegalConfig.privacyPolicyUrl to your public '
                            'policy page before uploading to Google Play.',
                            style: TextStyle(
                              color: AppColors.accent.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
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
