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

  /// Transport available (Wi‑Fi / cellular), even if probes fail.
  final ValueNotifier<bool> hasLink = ValueNotifier(true);

  /// Last successful HTTP reachability probe.
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
  /// Returns [hasInternet] (probe success). Use [hasLink] when you only need
  /// "is a network interface up?" (e.g. soft offline UX).
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
      final linkUp = results.isEmpty ||
          results.any((r) => r != ConnectivityResult.none);
      hasLink.value = linkUp;

      if (!linkUp) {
        hasInternet.value = false;
        return false;
      }

      // Web browsers block cross-origin XHR to generate_204 (CORS).
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
      // Probe result only — do not soft-lie as "online" when DNS/firewall blocks.
      hasInternet.value = ok;
      return ok;
    } catch (e, st) {
      debugPrint('Connectivity refresh failed: $e\n$st');
      // Unknown error: trust link if we have one.
      if (hasLink.value) {
        return hasInternet.value;
      }
      hasInternet.value = false;
      return false;
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
    hasLink.dispose();
  }
}
