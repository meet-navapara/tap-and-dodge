import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../campaign/campaign_models.dart';
import '../tap_dodge_game.dart';

/// Bright poison / acid hazard band — clearly labeled and hard to miss.
class ToxicBand extends PositionComponent with HasGameReference<TapDodgeGame> {
  ToxicBand()
    : super(size: Vector2(100, 72), anchor: Anchor.center, priority: 5);

  double _phase = 0;
  double _dwell = 0;
  final math.Random _rng = math.Random(7);
  late final List<_Drip> _drips;

  bool get _active {
    final m = game.currentSection.mechanic;
    return game.isGameplayActive &&
        (m == SectionMechanic.toxicBand || m == SectionMechanic.finaleStorm);
  }

  @override
  void onMount() {
    super.onMount();
    size = Vector2(game.size.x * 0.96, 78);
    position = Vector2(game.size.x / 2, game.size.y * 0.42);
    _drips = List.generate(
      10,
      (_) => _Drip(
        x: _rng.nextDouble(),
        delay: _rng.nextDouble() * 2,
        speed: 0.35 + _rng.nextDouble() * 0.45,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_active) {
      _dwell = 0;
      return;
    }

    _phase += dt * 3.2;
    position.x = game.size.x / 2;
    position.y =
        (game.size.y * 0.42) + math.sin(_phase * 0.5) * (game.size.y * 0.2);
    size = Vector2(game.size.x * 0.96, 78);

    for (final d in _drips) {
      d.t += dt * d.speed;
      if (d.t > 1.2 + d.delay) d.t = 0;
    }

    final player = game.player;
    final overlaps =
        (player.position.y - position.y).abs() <
            (size.y / 2 + player.size.y * 0.28) &&
        (player.position.x - position.x).abs() < size.x / 2;

    if (overlaps) {
      _dwell += dt;
      if (_dwell >= 1.0) {
        _dwell = 0;
        game.onPlayerHit();
      }
    } else {
      _dwell = math.max(0, _dwell - dt * 1.5);
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;

    final rect = Offset.zero & Size(size.x, size.y);
    final pulse = 0.45 + 0.35 * (0.5 + 0.5 * math.sin(_phase * 2.4));
    final danger = (_dwell / 1.0).clamp(0.0, 1.0);

    // Outer toxic glow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(8), const Radius.circular(22)),
      Paint()
        ..color = Color.fromRGBO(120, 255, 40, 0.22 + pulse * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Sludge fill.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.y),
          [
            Color.fromRGBO(180, 255, 60, 0.55 + pulse * 0.25),
            Color.fromRGBO(80, 200, 40, 0.4 + danger * 0.25),
            Color.fromRGBO(40, 120, 20, 0.35),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Hazard stripes.
    final stripe = Paint()
      ..color = Color.fromRGBO(20, 40, 10, 0.35)
      ..strokeWidth = 10;
    for (var i = -2; i < 14; i++) {
      final x = i * 42.0 + (_phase * 30 % 42);
      canvas.drawLine(Offset(x, 0), Offset(x + 36, size.y), stripe);
    }

    // Border that turns redder while the player is inside.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(16)),
      Paint()
        ..color = Color.lerp(
          const Color(0xFFB8FF3D),
          const Color(0xFFFF3B6B),
          danger,
        )!.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2,
    );

    // Drips.
    for (final d in _drips) {
      final progress = ((d.t - d.delay) / 1.0).clamp(0.0, 1.0);
      if (progress <= 0) continue;
      final dx = d.x * size.x;
      final dy = size.y * 0.2 + progress * (size.y * 0.9);
      canvas.drawCircle(
        Offset(dx, dy),
        3.5 * (1 - progress * 0.4),
        Paint()..color = Color.fromRGBO(190, 255, 80, 0.7 * (1 - progress)),
      );
    }

    // Bold POISON badge — impossible to miss.
    final tp = TextPainter(
      text: TextSpan(
        text: danger > 0.35 ? '⚠ POISON — MOVE!' : '☠ POISON ZONE',
        style: TextStyle(
          color: const Color(0xE6000000),
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final badge = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: tp.width + 22,
        height: tp.height + 12,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      badge,
      Paint()..color = Color.fromRGBO(255, 230, 80, 0.92),
    );
    tp.paint(
      canvas,
      Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2),
    );
  }
}

class _Drip {
  _Drip({required this.x, required this.delay, required this.speed});

  final double x;
  final double delay;
  final double speed;
  double t = 0;
}
