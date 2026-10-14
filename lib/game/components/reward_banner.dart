import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../tap_dodge_game.dart';

/// Big floating "2x REWARD" / "SHIELD" pop after a rewarded continue.
class RewardBanner extends PositionComponent
    with HasGameReference<TapDodgeGame> {
  RewardBanner({
    required this.label,
    required this.accent,
    this.duration = 1.6,
    Vector2? position,
    this.compact = false,
  }) : super(
         position: position ?? Vector2.zero(),
         size: compact ? Vector2(72, 40) : Vector2(280, 64),
         anchor: Anchor.center,
         priority: 80,
       );

  final String label;
  final Color accent;
  final double duration;
  final bool compact;
  double _life = 0;
  bool _placed = false;

  @override
  void onMount() {
    super.onMount();
    if (!_placed && position.length2 < 1) {
      position = Vector2(game.size.x / 2, game.size.y * 0.34);
    }
    _placed = true;
    _life = duration;
  }

  @override
  void update(double dt) {
    _life -= dt;
    position.y -= 28 * dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    final pop = 0.85 + 0.15 * math.sin((1 - t) * math.pi);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(pop, pop);
    canvas.translate(-size.x / 2, -size.y / 2);

    final rect = RRect.fromRectAndRadius(
      Offset.zero & Size(size.x, size.y),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = accent.withValues(alpha: 0.35 * t)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = Color.fromRGBO(10, 16, 36, 0.82 * t),
    );
    canvas.drawRRect(
      rect.deflate(2),
      Paint()
        ..color = accent.withValues(alpha: 0.95 * t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: accent.withValues(alpha: t),
          fontSize: compact ? 22 : 26,
          fontWeight: FontWeight.w900,
          letterSpacing: compact ? 0.5 : 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x - 16);
    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
    canvas.restore();
  }
}
