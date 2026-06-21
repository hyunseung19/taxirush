import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/game_engine.dart';

class HudOverlay extends StatelessWidget {
  final GameEngine engine;
  const HudOverlay({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final gs = engine.gameState;
    final remaining = engine.remainingToLevelUp;
    final progress = engine.levelProgress;

    return SafeArea(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: engine.config.accentColor.withValues(alpha: 0.42),
              ),
            ),
            child: Row(
              children: [
                _HudItem(
                  icon: Icons.star,
                  iconColor: Colors.amber,
                  label: 'SCORE',
                  value: '${gs.score}',
                ),
                const SizedBox(width: 12),
                _divider(),
                const SizedBox(width: 12),
                _HudItem(
                  icon: Icons.payments,
                  iconColor: const Color(0xFF56F0B2),
                  label: 'CASH',
                  value: '\$${gs.cash}',
                ),
                const SizedBox(width: 12),
                _divider(),
                const SizedBox(width: 12),
                _HudItem(
                  icon: Icons.layers,
                  iconColor: engine.config.accentColor,
                  label: 'LEVEL',
                  value: '${gs.level}/${engine.config.totalLevels}',
                ),
                const SizedBox(width: 12),
                _divider(),
                const SizedBox(width: 12),
                _LifeMeter(lives: gs.lives),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: engine.config.primaryColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: engine.config.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    engine.config.name.toUpperCase(),
                    style: TextStyle(
                      color: engine.config.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _MeterRow(
            icon: Icons.person,
            label: 'PICKUP TARGET',
            value: '$remaining LEFT',
            progress: progress.clamp(0.0, 1.0),
            color: engine.config.accentColor,
          ),
          _MeterRow(
            icon: Icons.flash_on,
            label: engine.isBoosting ? 'BOOST ACTIVE' : 'SHIFT BOOST',
            value: '${(engine.boostCharge * 100).round()}%',
            progress: engine.boostCharge.clamp(0.0, 1.0),
            color: engine.isBoosting
                ? const Color(0xFFFFD600)
                : const Color(0xFF4FC3F7),
            glow: engine.isBoosting,
          ),
          if (engine.dangerLevel > 0.18)
            _PoliceAlert(animTime: engine.animTime, danger: engine.dangerLevel),
          if (engine.dangerLevel <= 0.18)
            _CompactStatus(
              icon: Icons.radar,
              label:
                  'CLEAR  |  WHEEL ${engine.wheelLevel}  |  INV ${engine.invisibilityItems}  |  AMMO ${engine.gunAmmo}',
              color: const Color(0xFF56F0B2),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: gs.levelCompleted
                ? _LevelUpBanner(key: const ValueKey('lvlup'), level: gs.level)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: Colors.white12);
}

class _HudItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _HudItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MeterRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double progress;
  final Color color;
  final bool glow;

  const _MeterRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: glow ? color.withValues(alpha: 0.8) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          SizedBox(
            width: 94,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: glow ? color : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ProgressBar(progress: progress, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifeMeter extends StatelessWidget {
  final int lives;
  const _LifeMeter({required this.lives});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_taxi, color: Color(0xFFFFD600), size: 16),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TAXI LIFE',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: List.generate(3, (i) {
                final active = i < lives;
                return Container(
                  width: 18,
                  height: 7,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? Color.lerp(
                            const Color(0xFF56F0B2),
                            const Color(0xFFFF1744),
                            (3 - lives).clamp(0, 3) / 3,
                          )
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactStatus extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactStatus({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;

  const _ProgressBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _PoliceAlert extends StatelessWidget {
  final double animTime;
  final double danger;
  const _PoliceAlert({required this.animTime, required this.danger});

  @override
  Widget build(BuildContext context) {
    final pulse = (math.sin(animTime * (8 + danger * 8)) + 1) / 2;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFFB71C1C).withValues(alpha: 0.55 + danger * 0.2),
          const Color(0xFFFF1744).withValues(alpha: 0.82 + danger * 0.12),
          pulse,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.45 + pulse * 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            danger > 0.7 ? 'POLICE CLOSING IN' : 'POLICE CHASING',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.local_police, color: Colors.white, size: 16),
        ],
      ),
    );
  }
}

// ── Left-side item bar ────────────────────────────────────────────────────────

class ItemBar extends StatelessWidget {
  final GameEngine engine;
  const ItemBar({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final invis = engine.invisibilitySecondsLeft;
    final items = [
      _ItemSlot(
        icon: Icons.settings_input_component,
        color: const Color(0xFF4FC3F7),
        count: 'LV${engine.wheelLevel}',
        active: engine.wheelLevel > 0,
      ),
      _ItemSlot(
        icon: Icons.airline_seat_recline_extra,
        color: const Color(0xFF56F0B2),
        count: '+${engine.seatUpgrades}',
        active: engine.seatUpgrades > 0,
      ),
      _ItemSlot(
        icon: Icons.visibility_off,
        color: const Color(0xFFCE93D8),
        count: invis > 0 ? '${invis.ceil()}s' : '×${engine.invisibilityItems}',
        active: engine.isInvisible || engine.invisibilityItems > 0,
        glowing: engine.isInvisible,
      ),
      _ItemSlot(
        icon: Icons.gps_fixed,
        color: const Color(0xFFFF7043),
        count: '×${engine.gunAmmo}',
        active: engine.gunAmmo > 0,
      ),
    ];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map(
              (slot) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: slot,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ItemSlot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String count;
  final bool active;
  final bool glowing;

  const _ItemSlot({
    required this.icon,
    required this.color,
    required this.count,
    this.active = false,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = active ? 1.0 : 0.35;
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: glowing ? 0.9 : (active ? 0.45 : 0.18)),
          width: glowing ? 1.5 : 1,
        ),
        boxShadow: glowing
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: opacity), size: 18),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              color: Colors.white.withValues(alpha: opacity),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelUpBanner extends StatelessWidget {
  final int level;
  const _LevelUpBanner({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD600).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD600).withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.arrow_upward, color: Color(0xFFFFD600), size: 14),
          const SizedBox(width: 8),
          const Text(
            'LEVEL UP!',
            style: TextStyle(
              color: Color(0xFFFFD600),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'LEVEL $level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
