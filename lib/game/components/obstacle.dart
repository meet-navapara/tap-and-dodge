import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../levels/level_config.dart';
import '../tap_dodge_game.dart';

/// Neon hazard shard — clearly dangerous, never coin-like.
class Obstacle extends PositionComponent
    with CollisionCallbacks, HasGameReference<TapDodgeGame> {
  Obstacle({
    required Vector2 position,
    required this.style,
    required this.fallSpeed,
  }) : super(
         position: position,
         size: Vector2(38, 38),
         anchor: Anchor.center,
         priority: 10,
       );

  final HazardStyle style;
  final double fallSpeed;

  bool _scored = false;
  double _phase = math.Random().nextDouble() * math.pi * 2;
  double _impact = 0;

  void playImpact() {
    _impact = 0.28;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Slightly inside the pulsed visual (scale 0.9–1.0) so grazes feel fair.
    add(
      CircleHitbox(
        radius: 16,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * (style == HazardStyle.spinner ? 5.2 : 3.6);
    if (_impact > 0) {
      _impact = math.max(0, _impact - dt);
    }

    if (!game.isGameplayActive) return;

    position.y += fallSpeed * dt;

    if (style == HazardStyle.drifter) {
      position.x += math.sin(_phase) * 48 * dt;
      position.x = position.x.clamp(24, game.size.x - 24);
    }

    if (!_scored && position.y - size.y / 2 > game.size.y) {
      _scored = true;
      game.onObstacleDodged();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final pulse = 0.9 + 0.1 * math.sin(_phase);
    final spin = style == HazardStyle.spinner ? _phase * 0.4 : 0.0;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(spin);
    canvas.scale(pulse, pulse);
    canvas.translate(-size.x / 2, -size.y / 2);

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(12),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x66FF3B6B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B8A), Color(0xFFFF3B6B), Color(0xFFB01040)],
        ).createShader(rect),
    );

    // Warning chevron — distinct from gold coins.
    final warning = Path()
      ..moveTo(size.x / 2, 8)
      ..lineTo(size.x - 8, size.y - 9)
      ..lineTo(8, size.y - 9)
      ..close();
    canvas.drawPath(
      warning,
      Paint()
        ..color = const Color(0xEEFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(size.x / 2, size.y * 0.64),
      2.0,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    if (_impact > 0) {
      canvas.drawRRect(
        rrect,
        Paint()..color = Color.fromRGBO(255, 255, 255, 0.5 * (_impact / 0.28)),
      );
    }

    canvas.restore();
  }
}
