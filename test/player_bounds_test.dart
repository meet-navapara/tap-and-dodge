import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_and_dodge/game/playfield.dart';

void main() {
  test('playfield clamps keep the player inside a reachable rectangle', () {
    final world = Vector2(360, 740);

    expect(
      Playfield.minY(world),
      Playfield.topHudPadding + Playfield.playerRadius,
    );
    expect(Playfield.maxY(world), lessThan(world.y));

    final topLeft = Playfield.clamp(Vector2(-50, -50), world);
    expect(topLeft.x, Playfield.minX(world));
    expect(topLeft.y, Playfield.minY(world));

    final bottomRight = Playfield.clamp(Vector2(999, 999), world);
    expect(bottomRight.x, Playfield.maxX(world));
    expect(bottomRight.y, Playfield.maxY(world));
  });

  test('coins always spawn above the visible top edge', () {
    expect(Playfield.coinSpawnY, lessThan(0));
  });
}
