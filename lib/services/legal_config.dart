/// Store / privacy knobs. Replace URLs before Play publish.
class LegalConfig {
  const LegalConfig._();

  /// Hosted privacy policy. Leave empty to use the in-app policy screen only.
  /// Play Console still expects a public URL when ads are enabled.
  static const String privacyPolicyUrl = '';

  /// Hosted terms of service. Optional until Play listing requires it.
  static const String termsOfServiceUrl = '';

  static const String appName = 'Tap & Dodge';
  static const String supportEmail = '';

  static bool get hasHostedPrivacyPolicy => privacyPolicyUrl.trim().isNotEmpty;

  static bool get hasHostedTerms => termsOfServiceUrl.trim().isNotEmpty;
}
