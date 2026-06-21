import 'dart:math' as math;
import 'package:flutter/material.dart';

class MapClearOverlay extends StatefulWidget {
  final int score;
  final int delivered;
  final String mapName;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  const MapClearOverlay({
    super.key,
    required this.score,
    required this.delivered,
    required this.mapName,
    required this.onRetry,
    required this.onMenu,
  });

  @override
  State<MapClearOverlay> createState() => _MapClearOverlayState();
}

class _MapClearOverlayState extends State<MapClearOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Opacity(
        opacity: _fade.value,
        child: Container(
          color: Colors.black.withValues(alpha: 0.82),
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D2700), Color(0xFF1B4300)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF76FF03).withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF76FF03).withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ConfettiIcon(),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [
                          Color(0xFFFFD600),
                          Color(0xFF76FF03),
                          Color(0xFFFFD600),
                        ],
                      ).createShader(b),
                      child: const Text(
                        'MAP CLEARED!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF76FF03).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF76FF03).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        widget.mapName.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF76FF03),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          _StatRow(
                            icon: Icons.star,
                            color: Colors.amber,
                            label: '최종 점수',
                            value: '${widget.score}',
                          ),
                          const Divider(color: Colors.white10, height: 20),
                          _StatRow(
                            icon: Icons.person,
                            color: const Color(0xFF76FF03),
                            label: '총 태운 승객',
                            value: '${widget.delivered} 명',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _GameButton(
                      label: '다시 플레이',
                      icon: Icons.refresh,
                      color: const Color(0xFF2E7D32),
                      onTap: widget.onRetry,
                    ),
                    const SizedBox(height: 12),
                    _GameButton(
                      label: '맵 선택',
                      icon: Icons.map,
                      color: const Color(0xFF37474F),
                      onTap: widget.onMenu,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiIcon extends StatefulWidget {
  @override
  State<_ConfettiIcon> createState() => _ConfettiIconState();
}

class _ConfettiIconState extends State<_ConfettiIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        size: const Size(88, 88),
        painter: _ConfettiPainter(_ctrl.value),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Trophy icon background
    canvas.drawCircle(
      Offset(cx, cy),
      36,
      Paint()..color = const Color(0xFF76FF03).withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      36,
      Paint()
        ..color = const Color(0xFF76FF03).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Orbiting stars
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi + t * 2 * math.pi;
      final r = 42.0;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      final starR = 5.0 + math.sin(t * math.pi * 2 + i) * 2;
      canvas.drawCircle(
        Offset(x, y),
        starR,
        Paint()
          ..color = HSVColor.fromAHSV(1.0, (i / 6) * 360, 1.0, 1.0).toColor(),
      );
    }

    // Trophy icon (simplified)
    final tPaint = Paint()..color = Colors.amber;
    // Cup body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 4), width: 28, height: 22),
        const Radius.circular(4),
      ),
      tPaint,
    );
    // Stem
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + 12), width: 6, height: 10),
      tPaint,
    );
    // Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 18), width: 22, height: 5),
        const Radius.circular(2),
      ),
      tPaint,
    );
    // Star on cup
    _drawStar(
      canvas,
      Offset(cx, cy - 4),
      6,
      Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final a = (i * 4 * math.pi / 5) - math.pi / 2;
      final ia = a + 2 * math.pi / 5;
      if (i == 0) {
        path.moveTo(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      } else {
        path.lineTo(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      }
      path.lineTo(c.dx + r / 2 * math.cos(ia), c.dy + r / 2 * math.sin(ia));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _GameButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GameButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.color,
              Color.lerp(widget.color, Colors.black, 0.3)!,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
