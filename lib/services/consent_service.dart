import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Google UMP consent before ads (required for EEA/UK when using AdMob).
class ConsentService {
  bool _completed = false;
  Future<void>? _inFlight;

  /// Requests consent info and shows the form when required.
  /// Safe to call with test AdMob IDs; no-ops on failure.
  Future<void> gatherConsent({bool force = false}) async {
    if (kIsWeb) {
      _completed = true;
      return;
    }
    if (_completed && !force) return;
    if (_inFlight != null) return _inFlight!;

    _inFlight = _doGather();
    try {
      await _inFlight;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _doGather() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters(
      consentDebugSettings: kDebugMode && AdConfig.testDeviceIds.isNotEmpty
          ? ConsentDebugSettings(testIdentifiers: AdConfig.testDeviceIds)
          : null,
    );

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

    var timedOut = false;
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        timedOut = true;
        debugPrint('UMP consent timed out — will allow retry');
      },
    );
    // Only mark complete when the SDK finished; timeouts can retry.
    if (!timedOut) {
      _completed = true;
    }
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
