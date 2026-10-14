import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../campaign/campaign_models.dart';
import '../tap_dodge_game.dart';

/// Themed neon night backdrop driven by the active campaign world/section.
class StarfieldBackground extends Component
    with HasGameReference<TapDodgeGame> {
  final Random _random = Random(11);
  final List<_Star> _stars = [];
  double _haze = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _rebuildStars();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _rebuildStars();
  }

  void _rebuildStars() {
    _stars
      ..clear()
      ..addAll(
        List.generate(64, (i) {
          final layer = i < 28 ? 0 : (i < 48 ? 1 : 2);
          return _Star(
            Offset(
              _random.nextDouble() * game.size.x,
              _random.nextDouble() * game.size.y,
            ),
            0.5 + _random.nextDouble() * (1.2 + layer * 0.4),
            0.18 + _random.nextDouble() * 0.45,
            0.6 + _random.nextDouble() * 2.4,
            layer,
          );
        }),
      );
  }

  @override
  void update(double dt) {
    _haze += dt * 0.35;
    final mechanic = game.currentSection.mechanic;
    final rift =
        mechanic == SectionMechanic.riftPulse ||
        mechanic == SectionMechanic.finaleStorm;
    final storm = mechanic == SectionMechanic.finaleStorm;
    for (final star in _stars) {
      star.phase += dt * star.speed * (rift ? 1.4 : 1) * (storm ? 1.2 : 1);
      final drift = (0.8 + star.layer * 0.7) * dt * (rift ? 7 : 4);
      star.offset = Offset(
        (star.offset.dx + (rift ? sin(star.phase) * 8 * dt : 0)).clamp(
          0,
          game.size.x,
        ),
        (star.offset.dy + drift) % game.size.y,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final theme = game.worldTheme;
    final mechanic = game.currentSection.mechanic;
    final rect = Offset.zero & Size(game.size.x, game.size.y);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.bgTop,
            theme.bgMid,
            theme.bgBottom,
            const Color(0xFF050814),
          ],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ).createShader(rect),
    );

    // World accent orbs.
    final glowY = game.size.y * (0.72 + 0.02 * sin(_haze));
    canvas.drawCircle(
      Offset(game.size.x * 0.5, glowY),
      game.size.x * 0.55,
      Paint()
        ..color = theme.secondary.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    canvas.drawCircle(
      Offset(game.size.x * 0.2, game.size.y * 0.18),
      90,
      Paint()
        ..color = theme.primary.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );

    // Section-specific atmosphere (not just a recolor).
    switch (mechanic) {
      case SectionMechanic.laneSweep:
        _drawCyberGrid(canvas, theme);
      case SectionMechanic.toxicBand:
        _drawToxicHaze(canvas, theme);
      case SectionMechanic.riftPulse:
        _drawRiftBolts(canvas, theme);
      case SectionMechanic.finaleStorm:
        _drawCyberGrid(canvas, theme);
        _drawRiftBolts(canvas, theme);
        _drawToxicHaze(canvas, theme);
      case SectionMechanic.denseCoins:
        _drawCoinRainHints(canvas, theme);
      case SectionMechanic.none:
        break;
    }

    for (final star in _stars) {
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(star.phase));
      final tint = mechanic == SectionMechanic.toxicBand
          ? Color.fromRGBO(200, 255, 140, twinkle * star.opacity)
          : Color.fromRGBO(230, 236, 255, twinkle * star.opacity);
      canvas.drawCircle(star.offset, star.radius, Paint()..color = tint);
    }

    canvas.drawRect(
      Rect.fromLTWH(16, 66, game.size.x - 32, 1.5),
      Paint()..color = theme.primary.withValues(alpha: 0.28),
    );
  }

  void _drawCyberGrid(Canvas canvas, WorldTheme theme) {
    final paint = Paint()
      ..color = theme.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final step = 36.0;
    for (var x = 0.0; x < game.size.x; x += step) {
      canvas.drawLine(Offset(x, 70), Offset(x, game.size.y), paint);
    }
    final yShift = (_haze * 18) % step;
    for (var y = 70.0 - yShift; y < game.size.y; y += step) {
      canvas.drawLine(Offset(0, y), Offset(game.size.x, y), paint);
    }
  }

  void _drawToxicHaze(Canvas canvas, WorldTheme theme) {
    final bandY = game.size.y * (0.35 + 0.08 * sin(_haze * 1.4));
    canvas.drawRect(
      Rect.fromLTWH(0, bandY, game.size.x, 90),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.primary.withValues(alpha: 0.0),
            theme.primary.withValues(alpha: 0.12),
            theme.secondary.withValues(alpha: 0.08),
            theme.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, bandY, game.size.x, 90)),
    );
  }

  void _drawRiftBolts(Canvas canvas, WorldTheme theme) {
    final paint = Paint()
      ..color = theme.accent.withValues(alpha: 0.35 + 0.25 * sin(_haze * 6))
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final cx = game.size.x * (0.3 + 0.4 * (0.5 + 0.5 * sin(_haze * 2)));
    final path = Path()
      ..moveTo(cx, 80)
      ..lineTo(cx + 18, game.size.y * 0.35)
      ..lineTo(cx - 12, game.size.y * 0.55)
      ..lineTo(cx + 10, game.size.y * 0.78);
    canvas.drawPath(path, paint);
  }

  void _drawCoinRainHints(Canvas canvas, WorldTheme theme) {
    final paint = Paint()
      ..color = theme.accent.withValues(alpha: 0.12)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 6; i++) {
      final x = game.size.x * (0.15 + i * 0.14);
      final y = 90 + ((_haze * 40 + i * 28) % (game.size.y * 0.5));
      canvas.drawLine(Offset(x, y), Offset(x, y + 14), paint);
    }
  }
}

class _Star {
  _Star(this.offset, this.radius, this.opacity, this.speed, this.layer);

  Offset offset;
  final double radius;
  final double opacity;
  final double speed;
  final int layer;
  double phase = 0;
}
