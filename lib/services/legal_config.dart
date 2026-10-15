/// Store / privacy knobs — hosted on Firebase Hosting for Play Console.
class LegalConfig {
  const LegalConfig._();

  /// Public privacy policy (Firebase Hosting).
  static const String privacyPolicyUrl =
      'https://tapdodge-294f4.web.app/privacy/';

  /// Public terms of service (Firebase Hosting).
  static const String termsOfServiceUrl =
      'https://tapdodge-294f4.web.app/terms/';

  static const String appName = 'Tap & Dodge';
  static const String supportEmail = 'navaparameetdev@gmail.com';

  static bool get hasHostedPrivacyPolicy => privacyPolicyUrl.trim().isNotEmpty;

  static bool get hasHostedTerms => termsOfServiceUrl.trim().isNotEmpty;
}
