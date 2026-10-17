import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Monitors link state and verifies real internet reachability.
class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    http.Client? httpClient,
    this.reachabilityTimeout = const Duration(seconds: 4),
  }) : _connectivity = connectivity ?? Connectivity(),
       _http = httpClient ?? http.Client();

  final Connectivity _connectivity;
  final http.Client _http;
  final Duration reachabilityTimeout;

  /// Multiple endpoints — some networks/DNS block a single host.
  static const _probeUris = <String>[
    'https://www.gstatic.com/generate_204',
    'https://connectivitycheck.gstatic.com/generate_204',
    'https://clients3.google.com/generate_204',
  ];

  final ValueNotifier<bool> hasInternet = ValueNotifier(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Future<bool>? _ongoing;
  DateTime? _lastProbeAt;

  Future<void> start() async {
    await refresh();
    _sub ??= _connectivity.onConnectivityChanged.listen((_) {
      unawaited(refresh());
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Lightweight check: interface + occasional HTTP probe.
  ///
  /// Concurrent callers await the in-flight refresh. A [forceProbe] that
  /// arrives during an in-flight check waits, then runs a fresh probe.
  Future<bool> refresh({bool forceProbe = false}) async {
    if (_ongoing != null) {
      await _ongoing;
      if (!forceProbe) return hasInternet.value;
    }

    final future = _performRefresh(forceProbe: forceProbe);
    _ongoing = future;
    try {
      return await future;
    } finally {
      if (identical(_ongoing, future)) {
        _ongoing = null;
      }
    }
  }

  Future<bool> _performRefresh({required bool forceProbe}) async {
    try {
      final results = await _connectivity.checkConnectivity();
      // Treat "unknown/empty" and any non-none transport as a link.
      // Some Android builds briefly report [none] during USB debugging;
      // don't hard-fail ads/gameplay on that flicker.
      final hasLink = results.isEmpty ||
          results.any((r) => r != ConnectivityResult.none);

      if (!hasLink) {
        // Soft-allow once more: if we recently had internet, keep last value.
        if (_lastProbeAt != null &&
            DateTime.now().difference(_lastProbeAt!) <
                const Duration(seconds: 30) &&
            hasInternet.value) {
          return true;
        }
        hasInternet.value = false;
        return false;
      }

      // Web browsers block cross-origin XHR to generate_204 (CORS), so an HTTP
      // probe always fails in Chrome/Edge even when Wi‑Fi works. Trust the link.
      if (kIsWeb) {
        hasInternet.value = true;
        _lastProbeAt = DateTime.now();
        return true;
      }

      final now = DateTime.now();
      final shouldProbe =
          forceProbe ||
          _lastProbeAt == null ||
          now.difference(_lastProbeAt!) > const Duration(seconds: 12);
      if (!shouldProbe) {
        return hasInternet.value;
      }

      final ok = await _probeInternet();
      _lastProbeAt = now;
      // Soft-allow: if Wi‑Fi/cellular is up but probes fail (firewall/DNS),
      // still open the game — ads will no-op if truly offline.
      hasInternet.value = ok || hasLink;
      return hasInternet.value;
    } catch (e, st) {
      debugPrint('Connectivity refresh failed: $e\n$st');
      // Don't trap the player behind a false offline gate on unexpected errors.
      hasInternet.value = true;
      return true;
    }
  }

  Future<bool> _probeInternet() async {
    for (final uri in _probeUris) {
      try {
        final response = await _http
            .get(Uri.parse(uri))
            .timeout(reachabilityTimeout);
        if (response.statusCode == 204 || response.statusCode == 200) {
          return true;
        }
      } catch (_) {
        // try next endpoint
      }
    }
    return false;
  }

  void dispose() {
    unawaited(stop());
    _http.close();
    hasInternet.dispose();
  }
}
