import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Short gold spark burst when a coin is collected.
class PickupBurst extends PositionComponent {
  PickupBurst({required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(8),
        anchor: Anchor.center,
        priority: 30,
      );

  final Random _random = Random();
  late final List<_Particle> _particles;
  double _life = 0.32;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _particles = List.generate(12, (_) {
      final angle = _random.nextDouble() * pi * 2;
      final speed = 50 + _random.nextDouble() * 100;
      return _Particle(
        Offset(cos(angle) * speed, sin(angle) * speed),
        1.8 + _random.nextDouble() * 2.4,
      );
    });
  }

  @override
  void update(double dt) {
    _life -= dt;
    for (final p in _particles) {
      p.offset = Offset(
        p.offset.dx + p.velocity.dx * dt,
        p.offset.dy + p.velocity.dy * dt,
      );
    }
    if (_life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_life / 0.32).clamp(0.0, 1.0);
    for (final p in _particles) {
      canvas.drawCircle(
        p.offset,
        p.radius * alpha,
        Paint()..color = Color.fromRGBO(255, 215, 106, alpha),
      );
    }
  }
}

class _Particle {
  _Particle(this.velocity, this.radius);

  final Offset velocity;
  final double radius;
  Offset offset = Offset.zero;
}
