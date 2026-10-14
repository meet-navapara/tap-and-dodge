import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google UMP consent before ads (required for EEA/UK when using AdMob).
class ConsentService {
  bool _requested = false;

  /// Requests consent info and shows the form when required.
  /// Safe to call with test AdMob IDs; no-ops on failure.
  Future<void> gatherConsent() async {
    if (_requested) return;
    // UMP / Mobile Ads are not supported on Flutter web.
    if (kIsWeb) {
      _requested = true;
      return;
    }
    _requested = true;

    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint('UMP form error: ${formError.message}');
            }
          });
        } catch (e, st) {
          debugPrint('UMP show failed: $e\n$st');
        }
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        debugPrint('UMP update failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );
  }

  Future<bool> get canRequestAds async {
    if (kIsWeb) return false;
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return true;
    }
  }
}
