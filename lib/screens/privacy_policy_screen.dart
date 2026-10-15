import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/legal_config.dart';
import '../theme/app_theme.dart';

/// In-app privacy policy (ads + accounts). Host a public URL before Play upload.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openHosted() async {
    if (!LegalConfig.hasHostedPrivacyPolicy) return;
    final uri = Uri.parse(LegalConfig.privacyPolicyUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final contact = LegalConfig.supportEmail.trim().isEmpty
        ? 'Set LegalConfig.supportEmail before publishing'
        : LegalConfig.supportEmail;

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
                        const SizedBox(height: 8),
                        const Text(
                          'Last updated: for the current app build. '
                          'This in-app text must match your hosted Play Store '
                          'privacy policy URL.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '1) Local progress\n'
                          'Guest and signed-in play store campaign progress '
                          '(levels, coins, scores, skins, streak) in on-device '
                          'preferences on this phone.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '2) Google account (optional)\n'
                          'If you choose Continue with Google / Save My Progress, '
                          'we use Firebase Authentication with Google Sign-In. '
                          'We receive a Firebase user id and may receive your '
                          'Google display name, email, and profile photo URL from '
                          'Google. We use these to identify your account and show '
                          'your name in Account settings.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '3) Cloud save\n'
                          'Signed-in progress is stored in Google Cloud Firestore '
                          'under your Firebase user id so you can restore on another '
                          'device. Guest progress is not uploaded to a shared public '
                          'document.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '4) Ads\n'
                          'Internet is required for gameplay ads. We show rewarded, '
                          'interstitial, and app-open ads via Google AdMob. AdMob and '
                          'partners may process advertising ID, IP/device/network '
                          'signals, and interaction data to serve and measure ads.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '5) Consent\n'
                          'In the EEA/UK and similar regions we use Google\'s UMP '
                          'consent message before personalized ads when required. '
                          'You can also change device ad settings in system settings.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '6) Account deletion\n'
                          'Signed-in players can delete their Tap & Dodge account '
                          'data in Account → Delete Account & Cloud Save. That '
                          'removes the cloud save and the Firebase Auth link for '
                          'this app. It does not delete your Google Account.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '7) Children\n'
                          'This game is a general-audience casual arcade title and '
                          'is not directed at children under 13. Do not enroll the '
                          'app in Designed for Families / under-13 programs unless '
                          'you separately implement full Families / COPPA compliance '
                          '(including child-directed ad settings).',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '8) Selling data\n'
                          'We do not sell your personal information. Third-party SDKs '
                          '(AdMob, Firebase, Google Sign-In) process data under their '
                          'own policies as needed to provide ads and account features.',
                        ),
                        const SizedBox(height: 12),
                        Text('Contact: $contact'),
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
                            'Before Play upload: host this policy on a public HTTPS '
                            'URL and set LegalConfig.privacyPolicyUrl (Play requires '
                            'a link when the app uses ads / accounts).',
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
