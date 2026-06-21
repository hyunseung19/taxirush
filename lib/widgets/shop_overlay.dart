import 'package:flutter/material.dart';
import '../game/game_engine.dart';

class ShopOverlay extends StatelessWidget {
  final GameEngine engine;
  final VoidCallback onClose;

  const ShopOverlay({super.key, required this.engine, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Container(
          width: 360,
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF09111F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF56F0B2).withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.storefront, color: Color(0xFFFFD600)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'TAXI DEVELOPMENT SHOP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    '\$${engine.gameState.cash}',
                    style: const TextStyle(
                      color: Color(0xFF56F0B2),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── Scrollable item list ─────────────────────────────────────────
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.60,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShopItem(
                        icon: Icons.tire_repair,
                        title: 'Racing Wheels',
                        desc: '+ speed per upgrade level',
                        price: engine.wheelCost,
                        meta: 'Level ${engine.wheelLevel}',
                        onBuy: engine.buyWheel,
                      ),
                      _ShopItem(
                        icon: Icons.airline_seat_recline_extra,
                        title: 'Extra Seats',
                        desc: 'Carry +1 more passenger per upgrade',
                        price: engine.seatCost,
                        meta: engine.seatUpgrades >= 3
                            ? 'MAXED (${3 + engine.seatUpgrades} seats)'
                            : 'Capacity ${3 + engine.seatUpgrades} → ${4 + engine.seatUpgrades}',
                        onBuy: engine.buySeats,
                      ),
                      _ShopItem(
                        icon: Icons.visibility_off,
                        title: 'Ghost Mode',
                        desc: 'Use I: taxi turns invisible for 10 seconds',
                        price: 180,
                        meta: 'Owned ${engine.invisibilityItems}',
                        onBuy: engine.buyInvisibility,
                      ),
                      _ShopItem(
                        icon: Icons.gps_fixed,
                        title: 'Taxi Gun Ammo',
                        desc: 'Use Space: fire sky-blue bullet, push police',
                        price: 140,
                        meta: 'Ammo ${engine.gunAmmo}',
                        onBuy: engine.buyGunAmmo,
                      ),
                      _ShopItem(
                        icon: Icons.local_fire_department,
                        title: 'Shotgun Shell',
                        desc: 'Use G: blast — stuns ALL police within 3 tiles for 3 s',
                        price: 220,
                        meta: 'Shells ${engine.shotgunAmmo}',
                        onBuy: engine.buyShotgunAmmo,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('BACK TO DRIVE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD600),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final int price;
  final String meta;
  final bool Function() onBuy;

  const _ShopItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.price,
    required this.meta,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD600), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: const TextStyle(
                    color: Color(0xFF56F0B2),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onBuy,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF56F0B2),
              foregroundColor: Colors.black,
            ),
            child: Text('\$$price'),
          ),
        ],
      ),
    );
  }
}
