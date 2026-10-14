import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Full-screen gate when internet is unavailable.
class ConnectionRequiredScreen extends StatelessWidget {
  const ConnectionRequiredScreen({
    super.key,
    required this.onRetry,
    this.asOverlay = false,
  });

  final Future<void> Function() onRetry;
  final bool asOverlay;

  Future<void> _openNetworkSettings() async {
    // Best-effort Android settings deep link; safe no-op if unsupported.
    const channel = MethodChannel('tap_and_dodge/settings');
    try {
      await channel.invokeMethod<void>('openNetworkSettings');
    } catch (_) {
      try {
        await SystemChannels.platform.invokeMethod<void>(
          'SystemNavigator.routeInformationUpdated',
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.obstacle.withValues(alpha: 0.18),
            border: Border.all(
              color: AppColors.obstacle.withValues(alpha: 0.5),
            ),
          ),
          child: const Icon(
            Icons.wifi_off_rounded,
            size: 42,
            color: AppColors.obstacle,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Internet connection required.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          asOverlay
              ? 'Connection lost. Your progress is saved — reconnect to resume.'
              : 'Please connect to the internet to continue playing.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.softWhite.withValues(alpha: 0.7),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => onRetry(),
            child: const Text('RETRY'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _openNetworkSettings,
          child: const Text(
            'Open network settings',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );

    if (asOverlay) {
      return ColoredBox(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: body,
          ),
        ),
      );
    }

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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
