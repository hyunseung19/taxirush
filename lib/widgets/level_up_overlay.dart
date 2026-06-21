import 'dart:math' as math;
import 'package:flutter/material.dart';

class LevelUpOverlay extends StatefulWidget {
  final int level;
  const LevelUpOverlay({super.key, required this.level});

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
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
        opacity: _fadeAnim.value,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A237E), Color(0xFF283593)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF42A5F5).withOpacity(0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF42A5F5).withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StarBurst(),
                    const SizedBox(height: 12),
                    const Text(
                      'LEVEL UP!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF42A5F5).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        'LEVEL ${widget.level}',
                        style: const TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '경찰이 더 빨라집니다!\n준비하세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
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

class _StarBurst extends StatefulWidget {
  @override
  State<_StarBurst> createState() => _StarBurstState();
}

class _StarBurstState extends State<_StarBurst>
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
        size: const Size(80, 80),
        painter: _StarBurstPainter(_ctrl.value),
      ),
    );
  }
}

class _StarBurstPainter extends CustomPainter {
  final double t;
  _StarBurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // Rotating stars
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi + t * 2 * math.pi;
      final r = 28.0 + math.sin(t * math.pi * 2 + i) * 4;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      final starR = 6.0 + math.sin(t * math.pi * 2 + i * 0.5) * 2;
      paint.color = HSVColor.fromAHSV(1.0, (i / 8) * 360, 1.0, 1.0).toColor();
      _drawStar(canvas, Offset(x, y), starR, paint);
    }

    // Center star
    paint.color = Colors.white;
    _drawStar(
      canvas,
      Offset(cx, cy),
      16 + math.sin(t * math.pi * 4) * 3,
      paint,
    );
    paint.color = Colors.amber;
    _drawStar(
      canvas,
      Offset(cx, cy),
      12 + math.sin(t * math.pi * 4) * 2,
      paint,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final innerAngle = angle + 2 * math.pi / 5;
      if (i == 0) {
        path.moveTo(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
      } else {
        path.lineTo(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
      }
      path.lineTo(
        center.dx + r / 2 * math.cos(innerAngle),
        center.dy + r / 2 * math.sin(innerAngle),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarBurstPainter old) => true;
}
