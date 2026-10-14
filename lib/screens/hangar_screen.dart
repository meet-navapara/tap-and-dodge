import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/meta/ship_skins.dart';
import '../services/audio_service.dart';
import '../services/score_service.dart';
import '../theme/app_theme.dart';

/// Coin shop for cosmetic ship skins.
class HangarScreen extends StatefulWidget {
  const HangarScreen({
    super.key,
    required this.scoreService,
    required this.audioService,
  });

  final ScoreService scoreService;
  final AudioService audioService;

  @override
  State<HangarScreen> createState() => _HangarScreenState();
}

class _HangarScreenState extends State<HangarScreen> {
  String? _busyId;

  Future<void> _buyOrEquip(ShipSkin skin) async {
    if (_busyId != null) return;
    setState(() => _busyId = skin.id);
    await widget.audioService.playClick();

    final owned = widget.scoreService.ownsSkin(skin.id);
    if (!owned) {
      final ok = await widget.scoreService.purchaseSkin(skin.id);
      if (!mounted) return;
      if (!ok) {
        setState(() => _busyId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Need ${skin.cost} coins for ${skin.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      HapticFeedback.mediumImpact();
    }

    await widget.scoreService.equipSkin(skin.id);
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _busyId = null);
  }

  @override
  Widget build(BuildContext context) {
    final coins = widget.scoreService.totalCoins;
    final equipped = widget.scoreService.equippedSkinId;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101B45), AppColors.deepNavy, AppColors.midnight],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'HANGAR',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.panelBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: AppColors.coin,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$coins',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.coin,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Spend coins on ship skins. Equipped skin tints your flyer in-game.',
                  style: TextStyle(
                    color: AppColors.softWhite.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: ShipSkinCatalog.all.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final skin = ShipSkinCatalog.all[index];
                    final owned = widget.scoreService.ownsSkin(skin.id);
                    final isEquipped = equipped == skin.id;
                    final busy = _busyId == skin.id;

                    return Material(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: busy ? null : () => _buyOrEquip(skin),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isEquipped
                                  ? skin.mid
                                  : AppColors.panelBorder,
                              width: isEquipped ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [skin.primary, skin.mid, skin.deep],
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: skin.glow, blurRadius: 16),
                                  ],
                                ),
                                child: Icon(
                                  Icons.rocket_launch_rounded,
                                  color: skin.accent,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      skin.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      owned
                                          ? (isEquipped
                                                ? 'Equipped'
                                                : 'Owned · tap to equip')
                                          : '${skin.cost} coins',
                                      style: TextStyle(
                                        color: owned
                                            ? AppColors.player
                                            : AppColors.coin,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (busy)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              else if (isEquipped)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.player,
                                )
                              else if (owned)
                                const Icon(
                                  Icons.radio_button_unchecked_rounded,
                                  color: Colors.white54,
                                )
                              else
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: AppColors.accent,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
