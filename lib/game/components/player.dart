import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../meta/ship_skins.dart';
import '../playfield.dart';
import '../tap_dodge_game.dart';
import 'coin.dart';
import 'obstacle.dart';

/// Premium needle rocket — full-screen 2D drag control.
class Player extends PositionComponent
    with CollisionCallbacks, HasGameReference<TapDodgeGame> {
  Player({required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(50),
        anchor: Anchor.center,
        priority: 20,
      );

  static const double edgePadding = Playfield.edgePadding;
  static const double topHudPadding = Playfield.topHudPadding;

  double _pulse = 0;
  double _collectPulse = 0;
  bool _flash = false;
  double _flashTimer = 0;
  final Vector2 _lastPos = Vector2.zero();
  final Vector2 _velocity = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _lastPos.setFrom(position);
    // Slightly larger than before so visual contact matches a hit.
    add(
      CircleHitbox(
        radius: 18,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.active,
      ),
    );
  }

  void flashHit() {
    _flash = true;
    _flashTimer = 0.42;
  }

  void pulseCollect() {
    _collectPulse = 0.28;
  }

  /// Moves by [dx]/[dy] and returns actual displacement after playfield clamp.
  double moveByDelta(double dx, double dy) {
    if (!game.canControlPlayer) return 0;
    final before = position.clone();
    position = Playfield.clamp(
      Vector2(position.x + dx, position.y + dy),
      game.size,
    );
    return before.distanceTo(position);
  }

  void clampToBounds() {
    if (!isMounted) return;
    position = Playfield.clamp(position, game.size);
  }

  void resetToStart() {
    position = Vector2(game.size.x / 2, game.size.y * 0.72);
    clampToBounds();
    _lastPos.setFrom(position);
    _velocity.setZero();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Coin) {
      other.collect();
    } else if (other is Obstacle) {
      game.onPlayerHit();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 5.2;

    final safeDt = math.max(dt, 0.0001);
    _velocity.setValues(
      (position.x - _lastPos.x) / safeDt,
      (position.y - _lastPos.y) / safeDt,
    );
    _lastPos.setFrom(position);

    if (_collectPulse > 0) {
      _collectPulse = math.max(0, _collectPulse - dt);
    }
    if (_flash) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) _flash = false;
    }

    clampToBounds();
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final collectBoost = _collectPulse > 0 ? 1 + _collectPulse * 0.55 : 1.0;
    final speed = _velocity.length;
    final leanX = (_velocity.x / 480).clamp(-0.22, 0.22);
    final ShipSkin skin = game.scoreService.equippedSkin;
    final breath = 0.5 + 0.5 * math.sin(_pulse * 1.6);
    final thrust = 0.72 + (speed / 500).clamp(0.0, 0.4) + breath * 0.08;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(leanX);
    canvas.scale(collectBoost, collectBoost);
    canvas.translate(-center.dx, -center.dy);

    // Atmosphere halo — soft premium bloom.
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 2),
        width: 28 + breath * 2,
        height: 40,
      ),
      Paint()
        ..color = skin.glow.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    _drawPremiumPlume(canvas, center, skin, thrust);

    // Slim swept fins (behind hull).
    final finShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        skin.deep.withValues(alpha: 0.95),
        skin.mid,
        skin.deep.withValues(alpha: 0.95),
      ],
    ).createShader(Rect.fromLTWH(center.dx - 20, center.dy + 2, 40, 16));
    final finPaint = Paint()..shader = finShader;

    final leftFin = Path()
      ..moveTo(center.dx - 5.5, center.dy + 4)
      ..quadraticBezierTo(
        center.dx - 14,
        center.dy + 8,
        center.dx - 17,
        center.dy + 15,
      )
      ..quadraticBezierTo(
        center.dx - 9,
        center.dy + 13,
        center.dx - 5,
        center.dy + 11,
      )
      ..close();
    final rightFin = Path()
      ..moveTo(center.dx + 5.5, center.dy + 4)
      ..quadraticBezierTo(
        center.dx + 14,
        center.dy + 8,
        center.dx + 17,
        center.dy + 15,
      )
      ..quadraticBezierTo(
        center.dx + 9,
        center.dy + 13,
        center.dx + 5,
        center.dy + 11,
      )
      ..close();
    canvas.drawPath(leftFin, finPaint);
    canvas.drawPath(rightFin, finPaint);

    // Needle-body rocket hull.
    final hull = Path()
      ..moveTo(center.dx, center.dy - 21)
      ..cubicTo(
        center.dx + 7.5,
        center.dy - 14,
        center.dx + 8.8,
        center.dy - 2,
        center.dx + 8.2,
        center.dy + 8,
      )
      ..quadraticBezierTo(
        center.dx + 7.5,
        center.dy + 13.5,
        center.dx,
        center.dy + 14.5,
      )
      ..quadraticBezierTo(
        center.dx - 7.5,
        center.dy + 13.5,
        center.dx - 8.2,
        center.dy + 8,
      )
      ..cubicTo(
        center.dx - 8.8,
        center.dy - 2,
        center.dx - 7.5,
        center.dy - 14,
        center.dx,
        center.dy - 21,
      )
      ..close();

    final hullRect = Rect.fromLTWH(center.dx - 10, center.dy - 22, 20, 38);
    canvas.drawPath(
      hull,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [skin.deep, skin.primary, skin.mid, skin.deep],
          stops: const [0.0, 0.35, 0.62, 1.0],
        ).createShader(hullRect),
    );

    // Specular rim (premium metal sheen).
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 3.2, center.dy - 16)
        ..quadraticBezierTo(
          center.dx - 5.5,
          center.dy - 2,
          center.dx - 4.8,
          center.dy + 8,
        )
        ..quadraticBezierTo(
          center.dx - 3.2,
          center.dy - 2,
          center.dx - 2.2,
          center.dy - 14,
        )
        ..close(),
      Paint()..color = const Color(0x55FFFFFF),
    );

    // Thin gold / accent belt.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, 3.5),
          width: 12.5,
          height: 2.1,
        ),
        const Radius.circular(1.2),
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [
            skin.accent.withValues(alpha: 0.35),
            skin.accent,
            skin.accent.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromLTWH(center.dx - 7, center.dy + 2, 14, 3)),
    );

    // Glass canopy.
    final canopy = Rect.fromCenter(
      center: center.translate(0, -7.5),
      width: 8.5,
      height: 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(canopy, const Radius.circular(4)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xEEFFFFFF),
            skin.mid.withValues(alpha: 0.55),
            skin.deep.withValues(alpha: 0.75),
          ],
        ).createShader(canopy),
    );
    // Canopy glint.
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-1.6, -9.5),
        width: 3.2,
        height: 2.2,
      ),
      Paint()..color = const Color(0x99FFFFFF),
    );

    // Engine ring.
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 14.2),
        width: 11,
        height: 4.2,
      ),
      Paint()..color = const Color(0xFF1A2030),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 14.2),
        width: 7.5,
        height: 2.6,
      ),
      Paint()
        ..color = Color.lerp(
          skin.accent,
          const Color(0xFFFFF6D0),
          0.45,
        )!.withValues(alpha: 0.85 + 0.15 * breath),
    );

    if (_flash) {
      canvas.drawPath(hull, Paint()..color = const Color(0x88FF3B6B));
    } else if (_collectPulse > 0) {
      canvas.drawPath(
        hull,
        Paint()
          ..color = skin.accent.withValues(alpha: 0.35 * _collectPulse / 0.28),
      );
    }

    canvas.restore();
  }

  /// Soft plasma plume — elegant, not cartoon fire.
  void _drawPremiumPlume(
    Canvas canvas,
    Offset center,
    ShipSkin skin,
    double thrust,
  ) {
    final base = center.translate(0, 15.5);
    final length = 11 + 10 * thrust;
    final sway = math.sin(_pulse * 2.2) * 0.9;

    // Soft bloom behind plume.
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, length * 0.4),
        width: 16 + thrust * 4,
        height: length * 1.1,
      ),
      Paint()
        ..color = Color.lerp(
          skin.mid,
          const Color(0xFFFFB36A),
          0.35,
        )!.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    Path plume(double widthScale, double lengthScale) {
      final w = 5.2 * widthScale;
      final h = length * lengthScale;
      return Path()
        ..moveTo(base.dx - w, base.dy)
        ..cubicTo(
          base.dx - w * 0.55 + sway,
          base.dy + h * 0.35,
          base.dx - w * 0.2 + sway * 0.5,
          base.dy + h * 0.7,
          base.dx + sway * 0.25,
          base.dy + h,
        )
        ..cubicTo(
          base.dx + w * 0.2 - sway * 0.5,
          base.dy + h * 0.7,
          base.dx + w * 0.55 - sway,
          base.dy + h * 0.35,
          base.dx + w,
          base.dy,
        )
        ..close();
    }

    // Outer cool-to-warm veil
    canvas.drawPath(
      plume(1.15, 1.0),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            skin.primary.withValues(alpha: 0.55),
            Color.lerp(
              skin.accent,
              const Color(0xFFFF9A4A),
              0.5,
            )!.withValues(alpha: 0.7),
            const Color(0x00FF8A3D),
          ],
        ).createShader(Rect.fromLTWH(base.dx - 10, base.dy, 20, length + 6)),
    );

    // Inner hot core
    canvas.drawPath(
      plume(0.55, 0.82),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFFF8),
            Color.lerp(skin.accent, const Color(0xFFFFE8A8), 0.6)!,
            skin.mid.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(base.dx - 6, base.dy, 12, length)),
    );
  }
}
