import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_data.dart';
import '../models/game_models.dart';
import '../game/game_screen.dart';

class MapSelectScreen extends StatefulWidget {
  const MapSelectScreen({super.key});

  @override
  State<MapSelectScreen> createState() => _MapSelectScreenState();
}

class _MapSelectScreenState extends State<MapSelectScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _cardCtrl;
  Set<String> _unlockedMaps = {'downtown'};
  Map<String, int> _highScores = {};

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList('unlocked_maps') ?? ['downtown'];
    final scores = <String, int>{};
    for (final map in MapData.maps) {
      scores[map.id] = prefs.getInt('highscore_${map.id}') ?? 0;
    }
    setState(() {
      _unlockedMaps = Set.from(unlocked);
      _highScores = scores;
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _CityBgPainter(_bgCtrl.value),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Caution stripe header
                const _CautionStripe(height: 16),
                const SizedBox(height: 16),

                // Punk title
                _buildTitle(),

                const SizedBox(height: 14),
                const _CautionStripe(height: 8),
                const SizedBox(height: 8),

                // Map cards
                Expanded(
                  child: AnimatedBuilder(
                    animation: _cardCtrl,
                    builder: (context, _) => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: MapData.maps.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final map = MapData.maps[i];
                        final unlocked = _unlockedMaps.contains(map.id);
                        final highScore = _highScores[map.id] ?? 0;

                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, 0.25 + i * 0.08),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _cardCtrl,
                            curve: Interval(
                              i * 0.08, 0.55 + i * 0.08,
                              curve: Curves.easeOutCubic,
                            ),
                          )),
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 0, end: 1).animate(
                              CurvedAnimation(
                                parent: _cardCtrl,
                                curve: Interval(i * 0.08, 0.80),
                              ),
                            ),
                            child: _MapCard(
                              config: map,
                              unlocked: unlocked,
                              highScore: highScore,
                              onTap: unlocked
                                  ? () => _startGame(context, map)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Stacked TAXI / RUSH
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TAXI',
                style: TextStyle(
                  color: Color(0xFFFFCC00),
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 0.88,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: Color(0x99FF8800), blurRadius: 18),
                    Shadow(
                        color: Colors.black,
                        offset: Offset(3, 4),
                        blurRadius: 0),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: const Text(
                  'RUSH',
                  style: TextStyle(
                    color: Color(0xFFFF2800),
                    fontSize: 50,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    height: 0.85,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: Color(0x99880000), blurRadius: 14),
                      Shadow(
                          color: Colors.black,
                          offset: Offset(3, 4),
                          blurRadius: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Right side: vertical label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  color: const Color(0xFFFF2200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: const Text(
                    'SELECT ESCAPE ROUTE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '무면허 택시 · 경찰을 피해라',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startGame(BuildContext context, MapConfig config) {
    Navigator.of(context)
        .push(PageRouteBuilder(
          pageBuilder: (_, _, _) => GameScreen(config: config),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ))
        .then((_) => _loadProgress());
  }
}

// ── Caution tape stripe ───────────────────────────────────────────────────────

class _CautionStripe extends StatelessWidget {
  final double height;
  const _CautionStripe({this.height = 12});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _CautionPainter()),
    );
  }
}

class _CautionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.height * 1.4;
    final yP = Paint()..color = const Color(0xFFFFCC00);
    final bP = Paint()..color = const Color(0xFF111111);
    var x = -size.height;
    var i = 0;
    while (x < size.width + size.height) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + sw, 0)
          ..lineTo(x + sw - size.height, size.height)
          ..lineTo(x - size.height, size.height)
          ..close(),
        i.isEven ? yP : bP,
      );
      x += sw;
      i++;
    }
  }

  @override
  bool shouldRepaint(_CautionPainter _) => false;
}

// ── Map card ──────────────────────────────────────────────────────────────────

class _MapCard extends StatefulWidget {
  final MapConfig config;
  final bool unlocked;
  final int highScore;
  final VoidCallback? onTap;

  const _MapCard({
    required this.config,
    required this.unlocked,
    required this.highScore,
    required this.onTap,
  });

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final locked = !widget.unlocked;

    return GestureDetector(
      onTapDown: locked ? null : (_) => setState(() => _pressed = true),
      onTapUp: locked
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            },
      onTapCancel: locked ? null : () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (context, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
          decoration: BoxDecoration(
            color: locked ? const Color(0xFF0A0A0A) : const Color(0xFF111111),
            border: Border(
              left: BorderSide(
                color: locked
                    ? const Color(0xFF3A0A0A)
                    : const Color(0xFFFFCC00),
                width: 5,
              ),
              top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06), width: 0.5),
              right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06), width: 0.5),
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06), width: 0.5),
            ),
            boxShadow: locked
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFFFFCC00).withValues(
                          alpha: 0.07 + _glowCtrl.value * 0.08),
                      blurRadius: 24,
                      offset: const Offset(-6, 0),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // ── Card content ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    // Map icon (square, not circle)
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: locked
                            ? const Color(0xFF0A0A0A)
                            : c.primaryColor.withValues(alpha: 0.18),
                        border: Border.all(
                          color: locked
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFFFCC00)
                                  .withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: locked
                          ? const Icon(Icons.lock_outline,
                              color: Color(0x44FFFFFF), size: 24)
                          : _MapMiniPreview(config: c),
                    ),
                    const SizedBox(width: 14),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.name.toUpperCase(),
                                  style: TextStyle(
                                    color: locked
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : const Color(0xFFFFCC00),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              // Difficulty
                              Row(
                                children: List.generate(
                                  4,
                                  (i) => Text(
                                    i < c.difficulty ? '★' : '·',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: i < c.difficulty
                                          ? (locked
                                              ? Colors.white.withValues(
                                                  alpha: 0.15)
                                              : Colors.amber)
                                          : Colors.white
                                              .withValues(alpha: 0.10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.description,
                            style: TextStyle(
                              color: locked
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.40),
                              fontSize: 10.5,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 9),
                          if (!locked) ...[
                            Row(
                              children: [
                                _InfoChip(
                                  icon: Icons.local_police,
                                  label: '${c.policeCount} COPS',
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 6),
                                _InfoChip(
                                  icon: Icons.grid_on,
                                  label: '${c.gridWidth}×${c.gridHeight}',
                                  color: c.accentColor,
                                ),
                                const SizedBox(width: 6),
                                _InfoChip(
                                  icon: Icons.layers,
                                  label: 'LV${c.totalLevels}',
                                  color: Colors.amber,
                                ),
                              ],
                            ),
                            if (widget.highScore > 0) ...[
                              const SizedBox(height: 5),
                              Text(
                                '▶  BEST: ${widget.highScore}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ] else ...[
                            Text(
                              '// ${c.unlockRequirement.toUpperCase()} CLEAR REQUIRED',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.22),
                                fontSize: 9.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // RUN button
                    if (!locked) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCC00),
                          border: Border.all(
                              color: const Color(0xFF886600), width: 1),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'RUN',
                              style: TextStyle(
                                color: Color(0xFF0A0800),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              '▶',
                              style: TextStyle(
                                color: Color(0xFF0A0800),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── LOCKED stamp overlay ───────────────────────────────────────
              if (locked)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.22,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFAA0000), width: 2.5),
                            color: const Color(0x1AAA0000),
                          ),
                          child: const Text(
                            'LOCKED',
                            style: TextStyle(
                              color: Color(0xFFAA0000),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5,
                            ),
                          ),
                        ),
                      ),
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

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.38), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 9),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini map preview ──────────────────────────────────────────────────────────

class _MapMiniPreview extends StatelessWidget {
  final MapConfig config;
  const _MapMiniPreview({required this.config});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MiniMapPainter(config));
  }
}

class _MiniMapPainter extends CustomPainter {
  final MapConfig config;
  _MiniMapPainter(this.config);

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()..color = const Color(0xFF2A2A2A);
    final buildingPaint =
        Paint()..color = config.primaryColor.withValues(alpha: 0.55);
    final parkPaint =
        Paint()..color = const Color(0xFF1A4A1A).withValues(alpha: 0.7);

    final cellW = size.width / 8;
    final cellH = size.height / 8;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final isRoad = (r % 3 == 0) || (c % 3 == 0);
        final isPark = !isRoad && (c + r) % 5 == 0;
        canvas.drawRect(
          Rect.fromLTWH(
              c * cellW + 1, r * cellH + 1, cellW - 2, cellH - 2),
          isRoad ? roadPaint : isPark ? parkPaint : buildingPaint,
        );
      }
    }

    // Police dot
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.25),
      3.5,
      Paint()
        ..color = Colors.blue
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Taxi dot
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.65),
      3.5,
      Paint()
        ..color = const Color(0xFFFFCC00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── City background ───────────────────────────────────────────────────────────

class _CityBgPainter extends CustomPainter {
  final double t;
  _CityBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Dark gradient base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF030308), Color(0xFF060510), Color(0xFF0A0A08)],
          stops: [0.0, 0.60, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Purple city ambient glow
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.65),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.7),
          radius: 0.9,
          colors: const [Color(0x20AA00FF), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.65)),
    );

    // Stars (twinkle)
    final rng = math.Random(42);
    for (int i = 0; i < 90; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h * 0.52;
      final r = rng.nextDouble() * 1.4 + 0.4;
      final brightness = (math.sin(t * math.pi * 2 + i * 0.7) + 1) / 2;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color =
              Colors.white.withValues(alpha: 0.22 + brightness * 0.45),
      );
    }

    // Dense building silhouettes
    final buildingH = [
      90, 148, 68, 180, 112, 160, 78, 172, 96, 138, 58, 152, 105, 124, 88
    ];
    final bw = w / buildingH.length;

    for (int i = 0; i < buildingH.length; i++) {
      final bh = buildingH[i].toDouble();
      canvas.drawRect(
        Rect.fromLTWH(i * bw + 0.5, h - bh - 14, bw - 1, bh + 14),
        Paint()
          ..color = Color.fromARGB(
              255, 4 + (i * 3) % 8, 5 + (i * 2) % 10, 12 + (i * 5) % 22),
      );

      // Neon rooftop accent
      if (i % 3 == 0) {
        const neons = [
          Color(0x55FF00CC),
          Color(0x5500FFCC),
          Color(0x55FF5500),
        ];
        canvas.drawRect(
          Rect.fromLTWH(i * bw + 1, h - bh - 14, bw - 2, 3),
          Paint()
            ..color = neons[i % neons.length]
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      // Windows
      final rows = (bh / 18).floor();
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < 2; c++) {
          final lit =
              math.sin(t * math.pi * 2 + i * 1.3 + r * 0.7 + c) > 0.1;
          if (lit) {
            canvas.drawRect(
              Rect.fromLTWH(
                  i * bw + c * (bw / 2) + 4,
                  h - bh - 4 + r * 18,
                  bw / 2 - 8,
                  10),
              Paint()
                ..color =
                    const Color(0xFFFFEB3B).withValues(alpha: 0.52),
            );
          }
        }
      }
    }

    // Orange horizon glow
    canvas.drawRect(
      Rect.fromLTRB(0, h - 36, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFF4400).withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(0, h - 36, w, h)),
    );

    // Moving cars
    for (int i = 0; i < 4; i++) {
      final carX =
          (t * w * (0.38 + i * 0.18) + i * w / 4) % w;
      final isPolice = i == 1 || i == 3;
      // Headlight glow
      canvas.drawCircle(
        Offset(carX - 7, h - 11),
        7,
        Paint()
          ..color =
              (isPolice ? Colors.blue : const Color(0xFFFFCC00))
                  .withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(carX, h - 11), width: 18, height: 9),
          const Radius.circular(2),
        ),
        Paint()
          ..color = isPolice
              ? Colors.blue.withValues(alpha: 0.72)
              : const Color(0xFFFFCC00).withValues(alpha: 0.72),
      );
    }

    // Scan-line texture
    for (var y = 0.0; y < h; y += 4) {
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.08)
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(_CityBgPainter old) => old.t != t;
}
