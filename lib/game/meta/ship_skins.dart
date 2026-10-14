import 'package:flutter/material.dart';

/// Cosmetic ship skins purchasable with coins.
class ShipSkin {
  const ShipSkin({
    required this.id,
    required this.name,
    required this.cost,
    required this.primary,
    required this.mid,
    required this.deep,
    required this.glow,
    required this.accent,
  });

  final String id;
  final String name;
  final int cost;
  final Color primary;
  final Color mid;
  final Color deep;
  final Color glow;
  final Color accent;
}

class ShipSkinCatalog {
  static const defaultId = 'neon_cyan';

  static const List<ShipSkin> all = [
    ShipSkin(
      id: defaultId,
      name: 'Neon Cyan',
      cost: 0,
      primary: Color(0xFF9EFFFF),
      mid: Color(0xFF39F3FF),
      deep: Color(0xFF1B8CFF),
      glow: Color(0x6639F3FF),
      accent: Color(0xFFFFD76A),
    ),
    ShipSkin(
      id: 'vio_pulse',
      name: 'Vio Pulse',
      cost: 80,
      primary: Color(0xFFE9D5FF),
      mid: Color(0xFFC084FC),
      deep: Color(0xFF7C3AED),
      glow: Color(0x66C084FC),
      accent: Color(0xFFF0ABFC),
    ),
    ShipSkin(
      id: 'solar_flare',
      name: 'Solar Flare',
      cost: 120,
      primary: Color(0xFFFFF1C1),
      mid: Color(0xFFFFD76A),
      deep: Color(0xFFFF8A3D),
      glow: Color(0x66FFD76A),
      accent: Color(0xFFFF6B6B),
    ),
    ShipSkin(
      id: 'toxic_sting',
      name: 'Toxic Sting',
      cost: 160,
      primary: Color(0xFFE8FFB0),
      mid: Color(0xFFB8FF3D),
      deep: Color(0xFF65A30D),
      glow: Color(0x66B8FF3D),
      accent: Color(0xFFFF5C7A),
    ),
    ShipSkin(
      id: 'crimson_king',
      name: 'Crimson King',
      cost: 220,
      primary: Color(0xFFFFC9D4),
      mid: Color(0xFFFF3B6B),
      deep: Color(0xFFB01040),
      glow: Color(0x66FF3B6B),
      accent: Color(0xFFFFD76A),
    ),
  ];

  static ShipSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}
