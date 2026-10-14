import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../tap_dodge_game.dart';

/// Gold collectible that always falls from the top of the playfield.
class Coin extends PositionComponent
    with CollisionCallbacks, HasGameReference<TapDodgeGame> {
  Coin({required Vector2 position, required this.fallSpeed})
    : super(
        position: position,
        size: Vector2.all(32),
        anchor: Anchor.center,
        priority: 12,
      );

  final double fallSpeed;

  bool collected = false;
  double _spin = math.Random().nextDouble() * math.pi;
  double _shimmer = 0;
  double _collectAnim = 0;
  double opacity = 1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Hitbox closely matches the visible disk.
    add(
      CircleHitbox(
        radius: 12,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  void collect() {
    if (collected) return;
    collected = true;
    _collectAnim = 0.28;
    for (final hitbox in children.whereType<ShapeHitbox>()) {
      hitbox.collisionType = CollisionType.inactive;
    }
    game.onCoinCollected(position.clone());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _spin += dt * 5.5;
    _shimmer += dt * 4;

    if (collected) {
      _collectAnim -= dt;
      scale = Vector2.all(1 + (0.28 - _collectAnim) * 2.2);
      opacity = (_collectAnim / 0.28).clamp(0, 1).toDouble();
      if (_collectAnim <= 0) {
        removeFromParent();
      }
      return;
    }

    if (!game.isGameplayActive) return;

    // Primary motion: continuous downward fall (dt-based).
    position.y += fallSpeed * dt;
    // Tiny horizontal sway only — never teleports or random jumps.
    position.x += math.sin(_shimmer) * 10 * dt;
    position.x = position.x.clamp(22, game.size.x - 22);

    if (position.y - size.y / 2 > game.size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final squash = 0.78 + 0.22 * math.cos(_spin);
    final glowPulse = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(_shimmer));
    final accent = game.worldTheme.accent;
    final primary = game.worldTheme.primary;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(squash, 1);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawCircle(
      center,
      15,
      Paint()
        ..color = accent.withValues(alpha: 0.35 * opacity * glowPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    final disk = Rect.fromCircle(center: center, radius: 12.5);
    canvas.drawCircle(
      center,
      12.5,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.05,
          colors: [
            Color.fromRGBO(255, 248, 210, opacity),
            accent.withValues(alpha: opacity),
            primary.withValues(alpha: opacity * 0.85),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(disk),
    );

    canvas.drawCircle(
      center,
      8.5,
      Paint()
        ..color = primary.withValues(alpha: 0.45 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
    canvas.drawCircle(
      center,
      3.2,
      Paint()..color = accent.withValues(alpha: 0.9 * opacity),
    );

    canvas.drawCircle(
      center.translate(-3.8, -4.2),
      2.8,
      Paint()..color = Color.fromRGBO(255, 255, 255, 0.55 * opacity),
    );

    canvas.restore();
  }
}
