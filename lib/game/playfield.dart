import 'package:flame/components.dart';

/// Shared playable rectangle used by the player and spawners.
class Playfield {
  static const double edgePadding = 12;
  static const double topHudPadding = 78;
  static const double playerRadius = 24;

  /// Coins always begin just above the visible top edge.
  static const double coinSpawnY = -28;

  static double minX(Vector2 worldSize) => playerRadius + edgePadding;

  static double maxX(Vector2 worldSize) =>
      worldSize.x - playerRadius - edgePadding;

  static double minY(Vector2 worldSize) => playerRadius + topHudPadding;

  static double maxY(Vector2 worldSize) =>
      worldSize.y - playerRadius - edgePadding;

  static Vector2 clamp(Vector2 position, Vector2 worldSize) {
    return Vector2(
      position.x.clamp(minX(worldSize), maxX(worldSize)).toDouble(),
      position.y.clamp(minY(worldSize), maxY(worldSize)).toDouble(),
    );
  }
}
