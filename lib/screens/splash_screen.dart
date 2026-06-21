import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'map_select_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Splash / title screen  —  front-facing sedan  (chase composition)
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _road;
  late final AnimationController _siren;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _road = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _siren = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320))
      ..repeat();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _road.dispose();
    _siren.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onStart() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => const MapSelectScreen(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010208),
      body: AnimatedBuilder(
        animation: Listenable.merge([_road, _siren, _pulse]),
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _SplashPainter(
                roadPhase: _road.value,
                sirenPhase: _siren.value,
              ),
            ),
            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.40, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildTitle(),
                  const Spacer(),
                  _buildStartBtn(_pulse.value),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return SizedBox(
      width: double.infinity,
      height: 152,
      child: CustomPaint(painter: const _TitlePainter()),
    );
  }

  Widget _buildStartBtn(double pulse) {
    final g = 0.55 + 0.45 * pulse;
    return GestureDetector(
      onTap: _onStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 17),
        decoration: BoxDecoration(
          color: const Color(0xFFFFCC00),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFAA00).withValues(alpha: g * 0.75),
              blurRadius: 28 * g,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Text(
          'START GAME',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.5,
              color: Color(0xFF1A0A00)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _SplashPainter extends CustomPainter {
  final double roadPhase;
  final double sirenPhase;
  const _SplashPainter({required this.roadPhase, required this.sirenPhase});

  @override
  bool shouldRepaint(_SplashPainter o) =>
      o.roadPhase != roadPhase || o.sirenPhase != sirenPhase;

  static const double _vpXr    = 0.50;
  static const double _vpYr    = 0.32;
  static const double _rHW     = 90.0; // road half-width at VP level
  static const int    _nLanes  = 5;    // number of lanes

  // Perspective-correct lane-centre x at a given screen y.
  // laneFrac 0.0 = far left edge, 1.0 = far right edge.
  double _laneX(double w, double h, double carY, double laneFrac) {
    final vpx = w * _vpXr;
    final vpy = h * _vpYr;
    final t = ((carY - vpy) / (h + 60 - vpy)).clamp(0.0, 1.0);
    final xTop = vpx + _rHW * (2 * laneFrac - 1);
    final xBot = -50.0 + laneFrac * (w + 100);
    return xTop + (xBot - xTop) * t;
  }

  // Width of a single lane at depth y — car should fill ≤ this.
  double _laneW(double w, double h, double carY) {
    final vpy = h * _vpYr;
    final t = ((carY - vpy) / (h + 60 - vpy)).clamp(0.0, 1.0);
    final roadW = 2 * _rHW + (w + 100 - 2 * _rHW) * t;
    return roadW / _nLanes;
  }

  // Strobe pulse — quick rise, slower decay.
  // [phase] overrides the global sirenPhase (used for per-car light offsets).
  double _sirenAlpha(bool firstHalf, [double? phase]) {
    final p = phase ?? sirenPhase;
    if (firstHalf && p >= 0.5) return 0;
    if (!firstHalf && p < 0.5) return 0;
    final t = firstHalf ? p * 2 : (p - 0.5) * 2;
    return (t < 0.25 ? t / 0.25 : (1 - t) / 0.75).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    _drawBackground(canvas, w, h);
    _drawSkyline(canvas, w, h);
    _drawBuildings(canvas, w, h);
    _drawRoad(canvas, w, h);
    _drawRoadAtmosphere(canvas, w, h);

    // ── Police fleet: back→front, irregular depths & sizes, per-car light ────
    // yf = bottomY fraction, lf = lane fraction (0=far left, 1=far right)
    // fill = lane-width multiplier (varies for depth illusion)
    // lo = lightOffset (each car blinks at a different phase)

    void pc(double yf, double lf, double fill, double lo) {
      final y = h * yf;
      _drawFrontVehicle(canvas, _laneX(w, h, y, lf), y,
          _laneW(w, h, y) * fill,
          isPolice: true, roadPhase: roadPhase, lightOffset: lo);
    }

    //         y       lane    fill   lightOffset
    // Deep pack — tiny cars far back
    pc(0.400,  0.50,   0.58,  0.36); // centre deep
    pc(0.420,  0.80,   0.60,  0.72); // right deep
    pc(0.438,  0.18,   0.60,  0.14); // left deep
    // Mid pack — closing in from all lanes
    pc(0.462,  0.50,   0.68,  0.55); // centre mid
    pc(0.490,  0.88,   0.72,  0.28); // hard right
    pc(0.490,  0.12,   0.72,  0.81); // hard left
    pc(0.520,  0.65,   0.76,  0.47); // right-centre
    pc(0.520,  0.35,   0.76,  0.63); // left-centre
    // Close pack — flanking on outer edges
    pc(0.560,  0.96,   0.82,  0.19); // extreme right flank
    pc(0.560,  0.04,   0.82,  0.92); // extreme left flank
    pc(0.600,  0.74,   0.86,  0.34); // right close
    pc(0.600,  0.26,   0.86,  0.68); // left close
    pc(0.648,  0.50,   0.92,  0.08); // centre — right behind taxi

    // Taxi — centre lane (f=0.50), foreground
    final yTaxi = h * 0.82;
    _drawFrontVehicle(
      canvas, _laneX(w, h, yTaxi, 0.50), yTaxi,
      _laneW(w, h, yTaxi) * 0.88,
      isPolice: false,
      roadPhase: roadPhase,
    );
  }

  // ── Background + stars ───────────────────────────────────────────────────

  void _drawBackground(Canvas canvas, double w, double h) {
    final vpy = h * _vpYr;

    // Deep midnight sky — richer dark blue-black gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, vpy),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF000005),
            Color(0xFF030215),
            Color(0xFF0A0630),
            Color(0xFF150820),
          ],
          stops: const [0.0, 0.35, 0.72, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, vpy)),
    );

    // Road surface — wet asphalt with subtle dark shimmer
    canvas.drawRect(
      Rect.fromLTWH(0, vpy, w, h - vpy),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF0A0A18), Color(0xFF050508)],
        ).createShader(Rect.fromLTWH(0, vpy, w, h - vpy)),
    );

    // Horizon fire — wide orange-red city glow band
    canvas.drawRect(
      Rect.fromLTWH(0, vpy - 28, w, 56),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF3300).withValues(alpha: 0),
            const Color(0xFFFF6600).withValues(alpha: 0.60),
            const Color(0xFFFF2200).withValues(alpha: 0.30),
            const Color(0xFFFF3300).withValues(alpha: 0),
          ],
          stops: const [0.0, 0.42, 0.70, 1.0],
        ).createShader(Rect.fromLTWH(0, vpy - 28, w, 56)),
    );

    // Pollution haze — brownish smog layer hugging the skyline
    canvas.drawRect(
      Rect.fromLTWH(0, vpy * 0.55, w, vpy * 0.55),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A0A00).withValues(alpha: 0),
            const Color(0xFF1A0A00).withValues(alpha: 0.38),
          ],
        ).createShader(Rect.fromLTWH(0, vpy * 0.55, w, vpy * 0.55)),
    );

    // Purple city-ambient bloom
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, vpy),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.05, 0.80),
          radius: 0.75,
          colors: const [Color(0x2ACC00FF), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, 0, w, vpy)),
    );

    // Stars — denser near top, fewer near smoggy horizon
    final rng = math.Random(777);
    for (var i = 0; i < 140; i++) {
      final sy = rng.nextDouble() * vpy * 0.92;
      final fadeByHeight = 1.0 - sy / (vpy * 0.92);
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, sy),
        0.3 + rng.nextDouble() * 1.2,
        Paint()
          ..color = Colors.white.withValues(
              alpha: (0.15 + rng.nextDouble() * 0.65) * fadeByHeight),
      );
    }

    // Searchlight beams — sharper, more dramatic
    for (var i = 0; i < 4; i++) {
      final bx = w * (0.08 + i * 0.28);
      final bAlpha = 0.04 + (i % 2) * 0.02;
      canvas.drawPath(
        Path()
          ..moveTo(bx - 2.5, vpy * 0.82)
          ..lineTo(bx + 2.5, vpy * 0.82)
          ..lineTo(bx + 12, 0)
          ..lineTo(bx - 12, 0)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.white.withValues(alpha: bAlpha),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(bx - 12, 0, 24, vpy * 0.82)),
      );
    }
  }

  // ── Road atmosphere — wet reflections, neon puddles ──────────────────────

  void _drawRoadAtmosphere(Canvas canvas, double w, double h) {
    final vpx = w * _vpXr;
    final vpy = h * _vpYr;

    // Wet road shimmer: horizontal neon streaks reflecting off wet asphalt
    final rng = math.Random(42);
    const neonCols = [
      Color(0xFFFF00CC), Color(0xFF00DDFF),
      Color(0xFFFF4400), Color(0xFF88FF00), Color(0xFF9900FF),
    ];
    for (var i = 0; i < 18; i++) {
      final yf = vpy + (h - vpy) * (0.05 + rng.nextDouble() * 0.88);
      final t = ((yf - vpy) / (h - vpy)).clamp(0.0, 1.0);
      final roadLeft  = vpx - _rHW + (-50.0 - vpx + _rHW) * t;
      final roadRight = vpx + _rHW + (w + 50.0 - vpx - _rHW) * t;
      final nc = neonCols[rng.nextInt(neonCols.length)];
      final streak = (roadRight - roadLeft) * (0.04 + rng.nextDouble() * 0.22);
      final sx = roadLeft + rng.nextDouble() * (roadRight - roadLeft - streak);
      canvas.drawRect(
        Rect.fromLTWH(sx, yf - 0.8, streak, 1.6),
        Paint()
          ..color = nc.withValues(alpha: 0.06 + rng.nextDouble() * 0.11)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Police siren glow pools on road surface (blue / red alternating puddles)
    for (var i = 0; i < 5; i++) {
      final yf = vpy + (h - vpy) * (0.15 + i * 0.17);
      final t  = ((yf - vpy) / (h - vpy)).clamp(0.0, 1.0);
      final lane = 0.20 + i * 0.15;
      final px = vpx - _rHW + (-50.0 - vpx + _rHW) * t
               + lane * (2 * _rHW + (w + 100 - 2 * _rHW) * t);
      final isBlue = i.isEven;
      final gc = isBlue ? const Color(0xFF2244FF) : const Color(0xFFFF2233);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(px, yf),
          width: 60 + t * 120,
          height: 14 + t * 18,
        ),
        Paint()
          ..color = gc.withValues(alpha: 0.08 + t * 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
  }

  // ── Skyline silhouettes above VP (distant city canyon) ───────────────────

  void _drawSkyline(Canvas canvas, double w, double h) {
    final vpx = w * _vpXr, vpy = h * _vpYr;
    final rng = math.Random(13);

    for (final isLeft in [true, false]) {
      final xStart = isLeft ? 0.0 : vpx + _rHW;
      final xEnd   = isLeft ? vpx - _rHW : w;
      double x = xStart;

      while (x < xEnd) {
        final bw = 10.0 + rng.nextDouble() * 58.0;
        if (x + bw > xEnd + 10) break;
        final bh = 32.0 + rng.nextDouble() * (vpy * 0.95);

        // Dark silhouette block
        canvas.drawRect(
          Rect.fromLTRB(x, vpy - bh, x + bw, vpy + 2),
          Paint()
            ..color = Color.fromARGB(255,
              3 + rng.nextInt(10), 4 + rng.nextInt(14), 10 + rng.nextInt(28)),
        );

        // Window grid
        final wRows = math.max(1, (bh / 8.0).floor());
        final wCols = math.max(1, (bw / 7.0).floor());
        for (var r = 0; r < wRows; r++) {
          for (var c = 0; c < wCols; c++) {
            if (rng.nextDouble() < 0.26) {
              canvas.drawRect(
                Rect.fromCenter(
                  center: Offset(x + (c + 0.5) * bw / wCols,
                                 vpy - bh + (r + 0.6) * bh / wRows),
                  width: 2.5, height: 3.5,
                ),
                Paint()
                  ..color = rng.nextBool()
                      ? const Color(0x60FFEE88)
                      : const Color(0x50AADDFF),
              );
            }
          }
        }

        // Antenna on tall buildings
        if (bh > vpy * 0.42 && rng.nextDouble() < 0.45) {
          final antX = x + bw * 0.5;
          canvas.drawLine(
            Offset(antX, vpy - bh), Offset(antX, vpy - bh - 22),
            Paint()..color = const Color(0x55AAAACC)..strokeWidth = 0.9,
          );
          canvas.drawCircle(Offset(antX, vpy - bh - 22), 1.6,
              Paint()..color = const Color(0xAAFF4444));
        }

        // Neon sign strip
        if (rng.nextDouble() < 0.22 && bh > 30 && bw > 14) {
          const palette = [
            Color(0xFFFF00CC), Color(0xFF00FFEE),
            Color(0xFFAAFF00), Color(0xFFFF5500), Color(0xFF9955FF),
          ];
          final nc = palette[rng.nextInt(palette.length)];
          final ny = vpy - bh * (0.22 + rng.nextDouble() * 0.50);
          final nw = bw * (0.38 + rng.nextDouble() * 0.42);
          canvas.drawRect(
            Rect.fromCenter(center: Offset(x + bw / 2, ny), width: nw, height: 3.5),
            Paint()
              ..color = nc.withValues(alpha: 0.85)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }

        x += bw + rng.nextDouble() * 2.0; // nearly zero gap → tight pack
      }
    }
  }

  // ── Buildings (3-D perspective blocks, varied styles) ────────────────────
  //
  // Four building types along both road edges, very dense → city canyon feel.
  //   0 — Standard box
  //   1 — Tall slim tower + antenna
  //   2 — Wide low block with cornice
  //   3 — Stepped high-rise
  //
  // Outer face is LEFT of road for isLeft=true, RIGHT for isLeft=false.

  void _drawBuildings(Canvas canvas, double w, double h) {
    final vpx = w * _vpXr, vpy = h * _vpYr;

    for (final isLeft in [true, false]) {
      final rng = math.Random(isLeft ? 42 : 77);
      double t = 0.003;

      while (t < 0.97) {
        final dt    = 0.010 + rng.nextDouble() * 0.025;
        final tNear = t + dt;
        if (tNear > 0.98) break;

        // Road edge x / ground y at far and near depths
        double edgeX(double td) => isLeft
            ? vpx - _rHW + (-50.0 - vpx + _rHW) * td
            : vpx + _rHW + (w + 50.0 - vpx - _rHW) * td;
        double groundY(double td) => vpy + (h + 60 - vpy) * td;

        final rxFar  = edgeX(t);      final yFar  = groundY(t);
        final rxNear = edgeX(tNear);  final yNear = groundY(tNear);

        // Building type picked randomly
        final btype = rng.nextInt(4);

        // Base dimensions (perspective-scaled at tNear / t) — tall for city canyon
        final baseH = btype == 1 ? 280.0 + rng.nextDouble() * 200  // tower: very tall
                    : btype == 2 ? 90.0  + rng.nextDouble() * 110  // low block: taller
                    : btype == 3 ? 180.0 + rng.nextDouble() * 220  // high-rise: huge
                    :              140.0 + rng.nextDouble() * 200;  // standard: tall
        final baseW = btype == 1 ? 28.0 + rng.nextDouble() * 38    // tower: slim
                    : btype == 2 ? 70.0 + rng.nextDouble() * 90    // low: wide
                    :              44.0 + rng.nextDouble() * 70;

        final bhNear = baseH * tNear;  final bhFar  = baseH * t;
        final bwNear = baseW * tNear;  final bwFar  = baseW * t;

        // Colour palette — night city variants
        final ri = rng.nextInt;
        final wallC = btype == 1
            ? Color.fromARGB(255, 5+ri(6),  8+ri(12), 18+ri(30)) // blue-grey tower
            : btype == 2
            ? Color.fromARGB(255, 8+ri(10), 6+ri(8),  12+ri(18)) // brownish block
            : Color.fromARGB(255, 6+ri(9),  7+ri(11), 14+ri(26));
        final sideC = Color.fromARGB(255, 4+ri(5), 4+ri(6), 10+ri(16));
        const topC  = Color(0xFF07071A);
        final corniceC = Color.fromARGB(255, 12+ri(8), 12+ri(8), 22+ri(16));

        // Helper: draw one box (road-edge face + outer face + top face)
        void drawBox(double bh1Far, double bh1Near, double bw1Near, double bw1Far,
            Color wall, Color side, {bool roof = true}) {
          final o1Near = isLeft ? rxNear - bw1Near : rxNear + bw1Near;
          final o1Far  = isLeft ? rxFar  - bw1Far  : rxFar  + bw1Far;
          // Road-edge face
          canvas.drawPath(
            Path()
              ..moveTo(rxFar,  yFar)
              ..lineTo(rxNear, yNear)
              ..lineTo(rxNear, yNear - bh1Near)
              ..lineTo(rxFar,  yFar  - bh1Far)
              ..close(),
            Paint()..color = side,
          );
          // Outer face
          canvas.drawPath(
            Path()
              ..moveTo(rxNear, yNear)
              ..lineTo(o1Near, yNear)
              ..lineTo(o1Near, yNear - bh1Near)
              ..lineTo(rxNear, yNear - bh1Near)
              ..close(),
            Paint()..color = wall,
          );
          if (roof) {
            // Top face
            canvas.drawPath(
              Path()
                ..moveTo(rxFar,  yFar  - bh1Far)
                ..lineTo(rxNear, yNear - bh1Near)
                ..lineTo(o1Near, yNear - bh1Near)
                ..lineTo(o1Far,  yFar  - bh1Far)
                ..close(),
              Paint()..color = topC,
            );
          }
          // Roof edge
          canvas.drawLine(Offset(rxNear, yNear - bh1Near),
              Offset(o1Near, yNear - bh1Near),
              Paint()..color = const Color(0x28AAAACC)..strokeWidth = 0.8);
        }

        // ── Draw by type ─────────────────────────────────────────────────────
        if (btype == 3) {
          // Stepped: lower wide base + upper narrower tower
          final loBH  = bhNear * 0.52;  final loBHf = bhFar * 0.52;
          final loBW  = bwNear;          final loBWf = bwFar;
          final hiBH  = bhNear * 0.50;  final hiBHf = bhFar * 0.50;
          final hiBW  = bwNear * 0.58;  final hiBWf = bwFar * 0.58;

          drawBox(loBHf, loBH, loBW, loBWf, wallC, sideC, roof: false);

          // Upper box sits on top of lower box
          // Shift rxFar/rxNear upward by loB heights and draw again:
          // We approximate by drawing a separate path shifted in y
          final topOfLow = yNear - loBH;
          final topOfLowFar = yFar - loBHf;
          // Upper box (outer face only — the step is visible)
          final hiOutNear = isLeft ? rxNear - hiBW : rxNear + hiBW;
          final hiOutFar  = isLeft ? rxFar  - hiBWf : rxFar + hiBWf;
          canvas.drawPath(
            Path()
              ..moveTo(rxFar,     topOfLowFar)
              ..lineTo(rxNear,    topOfLow)
              ..lineTo(rxNear,    topOfLow    - hiBH)
              ..lineTo(rxFar,     topOfLowFar - hiBHf)
              ..close(),
            Paint()..color = sideC,
          );
          canvas.drawPath(
            Path()
              ..moveTo(rxNear,    topOfLow)
              ..lineTo(hiOutNear, topOfLow)
              ..lineTo(hiOutNear, topOfLow    - hiBH)
              ..lineTo(rxNear,    topOfLow    - hiBH)
              ..close(),
            Paint()..color = wallC,
          );
          // Step ledge (visible cornice between lower and upper)
          canvas.drawPath(
            Path()
              ..moveTo(rxFar,  topOfLowFar)
              ..lineTo(rxNear, topOfLow)
              ..lineTo(hiOutNear, topOfLow)
              ..lineTo(hiOutFar,  topOfLowFar)
              ..close(),
            Paint()..color = corniceC,
          );
          // Roof of upper
          canvas.drawPath(
            Path()
              ..moveTo(rxFar,     topOfLowFar - hiBHf)
              ..lineTo(rxNear,    topOfLow    - hiBH)
              ..lineTo(hiOutNear, topOfLow    - hiBH)
              ..lineTo(hiOutFar,  topOfLowFar - hiBHf)
              ..close(),
            Paint()..color = topC,
          );
          canvas.drawLine(Offset(rxNear, topOfLow - hiBH),
              Offset(hiOutNear, topOfLow - hiBH),
              Paint()..color = const Color(0x28AAAACC)..strokeWidth = 0.8);

        } else if (btype == 2) {
          // Low block with cornice ledge on top
          drawBox(bhFar, bhNear, bwNear, bwFar, wallC, sideC);
          // Cornice: slightly wider overhang
          final cornW = bwNear * 1.08;  final cornH = bhNear * 0.05;
          final cornOutNear = isLeft ? rxNear - cornW : rxNear + cornW;
          canvas.drawPath(
            Path()
              ..moveTo(rxNear,     yNear - bhNear)
              ..lineTo(cornOutNear, yNear - bhNear)
              ..lineTo(cornOutNear, yNear - bhNear - cornH)
              ..lineTo(rxNear,     yNear - bhNear - cornH)
              ..close(),
            Paint()..color = corniceC,
          );
        } else {
          // Standard box (type 0) or tall tower (type 1)
          drawBox(bhFar, bhNear, bwNear, bwFar, wallC, sideC);

          // Tower: add rooftop antenna
          if (btype == 1 && bwNear > 4) {
            final antX = isLeft ? rxNear - bwNear * 0.5 : rxNear + bwNear * 0.5;
            final antBot = yNear - bhNear;
            final antH   = bhNear * 0.12;
            canvas.drawLine(Offset(antX, antBot), Offset(antX, antBot - antH),
                Paint()
                  ..color = const Color(0x88AAAACC)
                  ..strokeWidth = 1.0 * tNear);
            canvas.drawCircle(Offset(antX, antBot - antH), 1.5 * tNear,
                Paint()..color = const Color(0xAAFF4444));
          }
        }

        // ── Windows on outer face ─────────────────────────────────────────────
        final wRows = (bhNear / 13.0).floor().clamp(1, 14);
        final wCols = (bwNear / 11.0).floor().clamp(1, 9);
        for (var r = 0; r < wRows; r++) {
          for (var c = 0; c < wCols; c++) {
            if (rng.nextDouble() < 0.38) {
              final frac = (c + 0.5) / wCols;
              final wx = isLeft ? rxNear - frac * bwNear : rxNear + frac * bwNear;
              final wy = (yNear - bhNear) + (r + 0.65) * bhNear / wRows;
              canvas.drawRect(
                Rect.fromCenter(
                    center: Offset(wx, wy),
                    width:  5.5 * tNear,
                    height: 7.0 * tNear),
                Paint()..color = rng.nextBool()
                    ? const Color(0x70FFEE88)
                    : const Color(0x60AACCFF),
              );
            }
          }
        }

        // ── Neon sign on outer face (city lights) ─────────────────────────────
        if (rng.nextDouble() < 0.32 && bwNear > 6.0) {
          final neonW  = bwNear * (0.35 + rng.nextDouble() * 0.45);
          final neonH  = math.max(2.5, neonW * 0.18);
          final neonCX = isLeft ? rxNear - bwNear * 0.50 : rxNear + bwNear * 0.50;
          final neonCY = yNear - bhNear * (0.35 + rng.nextDouble() * 0.42);
          const neonPalette = [
            Color(0xFFFF00CC), Color(0xFF00FFEE), Color(0xFFAAFF00),
            Color(0xFFFF5500), Color(0xFF8866FF),
          ];
          final nc = neonPalette[rng.nextInt(neonPalette.length)];
          // Bloom
          canvas.drawRect(
            Rect.fromCenter(center: Offset(neonCX, neonCY),
                            width: neonW * 2.0, height: neonH * 3.2),
            Paint()
              ..color = nc.withValues(alpha: 0.14)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
          );
          // Bar
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(neonCX, neonCY),
                              width: neonW, height: neonH),
              Radius.circular(neonH * 0.45),
            ),
            Paint()..color = nc.withValues(alpha: 0.90),
          );
        }

        t = tNear + 0.001 + rng.nextDouble() * 0.003;
      }
    }
  }

  // ── Road ─────────────────────────────────────────────────────────────────

  void _drawRoad(Canvas canvas, double w, double h) {
    final vpx = w * _vpXr, vpy = h * _vpYr;
    // Road body
    canvas.drawPath(
      Path()
        ..moveTo(vpx - _rHW, vpy)
        ..lineTo(vpx + _rHW, vpy)
        ..lineTo(w + 50, h + 60)
        ..lineTo(-50, h + 60)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1C2C), Color(0xFF090914)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Road edges
    final ep = Paint()
      ..strokeWidth = 2.0
      ..color = const Color(0x55FFFFFF);
    canvas.drawLine(Offset(vpx - _rHW, vpy), Offset(-50, h + 60), ep);
    canvas.drawLine(Offset(vpx + _rHW, vpy), Offset(w + 50, h + 60), ep);

    // ── Lane dividers ────────────────────────────────────────────────────────
    for (var k = 1; k < _nLanes; k++) {
      final f = k / _nLanes;
      // Top & bottom x of this divider line
      final xTop = vpx + _rHW * (2 * f - 1);
      final xBot = -50.0 + f * (w + 100);

      for (var i = 0; i < 16; i++) {
        final tRaw = ((i + (1.0 - roadPhase)) / 16.0) % 1.0;
        if (tRaw > 0.65) continue;
        final t1 = tRaw * tRaw;
        final t2 = ((tRaw + 0.04) * (tRaw + 0.04)).clamp(0.0, 1.0);
        final y1 = vpy + (h + 90 - vpy) * t1;
        final y2 = vpy + (h + 90 - vpy) * t2;
        if (y1 > h + 5) continue;
        final x1 = xTop + (xBot - xTop) * t1;
        final x2 = xTop + (xBot - xTop) * t2;
        canvas.drawLine(
          Offset(x1, y1.clamp(vpy, h + 90)),
          Offset(x2, y2.clamp(vpy, h + 90)),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35 + 0.30 * tRaw)
            ..strokeWidth = 1.5 + 3.0 * tRaw
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  // ── Car (front-facing sedan) ──────────────────────────────────────────────
  // roadPhase drives both headlight pulse and wheel scroll animation.

  void _drawFrontVehicle(
    Canvas canvas,
    double cx,
    double bottomY,
    double carW, {
    required bool isPolice,
    required double roadPhase,
    double lightOffset = 0.0, // per-car siren phase offset (0–1)
  }) {
    // ── Colours ─────────────────────────────────────────────────────────────
    final bodyColor = isPolice ? const Color(0xFFCDD9E8) : const Color(0xFFFFCC00);
    final bodyDark  = isPolice ? const Color(0xFF1A2634) : const Color(0xFF8A5800);
    final glassCol  = isPolice ? const Color(0xFF0D1E2E) : const Color(0xFF071422);
    final roofColor = isPolice ? const Color(0xFFDDE8F4) : const Color(0xFFFFE040);
    final hoodColor = Color.lerp(bodyColor, Colors.white, 0.35)!;

    // ── Y levels ────────────────────────────────────────────────────────────
    final bmpH  = carW * 0.07;
    final bdH   = carW * 0.29;
    final hoodH = carW * 0.06;
    final wshH  = carW * 0.22;
    final rfH   = carW * 0.08;

    final yBot  = bottomY;
    final yBmp  = yBot  - bmpH;
    final yBod  = yBmp  - bdH;
    final yHood = yBod  - hoodH;
    final yWshT = yHood - wshH;
    final yRfT  = yWshT - rfH;

    // ── Widths ───────────────────────────────────────────────────────────────
    final wBmp   = carW;
    final wBod   = carW * 0.97;
    final wHoodB = carW * 0.90;
    final wHoodT = carW * 0.82;
    final wWsh   = carW * 0.82;
    final wWshT  = carW * 0.70;
    final wRf    = carW * 0.62;

    Path trap(double y1, double w1, double y2, double w2) => Path()
      ..moveTo(cx - w1 / 2, y1)
      ..lineTo(cx + w1 / 2, y1)
      ..lineTo(cx + w2 / 2, y2)
      ..lineTo(cx - w2 / 2, y2)
      ..close();

    // ── Ground shadow ────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, yBot + 5),
          width: carW + 10,
          height: carW * 0.07),
      Paint()..color = Colors.black.withValues(alpha: isPolice ? 0.45 : 0.10),
    );

    // ── Wheels — side view (90° rotated: thin vertical cylinder) ─────────────
    // The car faces us, wheels are turned slightly so we see the tread edge.
    final whlR  = carW * 0.115;
    final whlY  = yBmp + whlR * 0.12;
    // Scroll offset so the tread pattern appears to move downward as road scrolls
    final treadScroll = roadPhase;

    for (final sign in [-1.0, 1.0]) {
      final wx = cx + sign * (carW / 2 + whlR * 0.06);

      // Shadow — police cars only; taxi bumper already has its own ground shadow
      if (isPolice) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(wx, whlY + whlR * 0.82),
              width: whlR * 1.6,
              height: whlR * 0.22),
          Paint()..color = Colors.black.withValues(alpha: 0.28),
        );
      }

      // ── Tire (thin vertical rounded rect — side-on view) ──────────────────
      final tW = whlR * 0.50;   // tread depth (narrow)
      final tH = whlR * 2.05;   // full diameter

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(wx, whlY), width: tW, height: tH),
          Radius.circular(tW * 0.50),
        ),
        Paint()..color = const Color(0xFF111120),
      );

      // Tread lines scrolling downward (clipped to tire rect)
      canvas.save();
      final clipRect = Rect.fromCenter(
          center: Offset(wx, whlY), width: tW + 1, height: tH + 1);
      canvas.clipRect(clipRect);
      const numLines = 7;
      for (var t = 0; t < numLines; t++) {
        // Each line scrolls from top to bottom based on treadScroll
        final frac = ((t / numLines) + treadScroll) % 1.0;
        final ly = (whlY - tH / 2) + frac * tH;
        canvas.drawLine(
          Offset(wx - tW * 0.44, ly),
          Offset(wx + tW * 0.44, ly),
          Paint()
            ..color = const Color(0xFF2A2A3C)
            ..strokeWidth = 1.2,
        );
      }
      canvas.restore();

      // Rim (small silver vertical pill in center — hub visible through rubber)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(wx, whlY), width: tW * 0.60, height: tH * 0.44),
          Radius.circular(tW * 0.30),
        ),
        Paint()..color = const Color(0xFFB0B8C2),
      );
      // Rim highlight
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(wx, whlY), width: tW * 0.60, height: tH * 0.44),
          Radius.circular(tW * 0.30),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.25),
      );
      // Center cap dot
      canvas.drawCircle(
        Offset(wx, whlY), tW * 0.18,
        Paint()..color = const Color(0xFF484860),
      );

      // Tire outline
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(wx, whlY), width: tW, height: tH),
          Radius.circular(tW * 0.50),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF303040),
      );

      // Wheel arch — police cars only (taxi body hides it cleanly without arches)
      if (isPolice) {
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(wx, whlY - whlR * 0.06),
              width: whlR * 2.44,
              height: whlR * 2.32),
          -math.pi * 0.80, math.pi * 0.60, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = bodyDark.withValues(alpha: 0.65),
        );
      }
    }

    // ── Hood top ─────────────────────────────────────────────────────────────
    canvas.drawPath(
      trap(yBod, wHoodB, yHood, wHoodT),
      Paint()..color = hoodColor,
    );
    canvas.drawPath(
      trap(yBod, wHoodB, yHood, wHoodT),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.black.withValues(alpha: 0.22),
    );

    // ── Bumper ───────────────────────────────────────────────────────────────
    canvas.drawPath(trap(yBot, wBmp, yBmp, wBmp), Paint()..color = bodyDark);

    if (isPolice) {
      // Bumper plate (license plate look)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, yBmp - bmpH * 0.35),
              width: carW * 0.28,
              height: bmpH * 0.11),
          Radius.circular(bmpH * 0.06),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );

      // ── Front push-bar / iron grill ────────────────────────────────────────
      // Horizontal frame rail
      final grillTop    = yBmp - bdH * 0.08;
      final grillBot    = yBmp + bmpH * 0.45;
      final grillLeft   = cx - wBmp * 0.46;
      final grillRight  = cx + wBmp * 0.46;
      final railPaint   = Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = carW * 0.024
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(grillLeft, grillTop), Offset(grillRight, grillTop), railPaint);
      canvas.drawLine(Offset(grillLeft, grillBot), Offset(grillRight, grillBot), railPaint);
      // Vertical bars
      const nBars = 5;
      final barPaint = Paint()
        ..color = const Color(0xFF222222)
        ..strokeWidth = carW * 0.016
        ..strokeCap = StrokeCap.butt;
      for (var i = 0; i < nBars; i++) {
        final f = i / (nBars - 1);
        final bx = grillLeft + f * (grillRight - grillLeft);
        canvas.drawLine(Offset(bx, grillTop), Offset(bx, grillBot), barPaint);
      }
      // Highlight sheen on bars
      canvas.drawLine(
        Offset(grillLeft, grillTop),
        Offset(grillRight, grillTop),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = carW * 0.006,
      );
    } else {
      // ── Taxi: UNREGISTERED license plate ───────────────────────────────────
      final plateW = carW * 0.38;
      final plateH = bmpH * 0.50;
      final plateCx = cx;
      final plateCy = yBmp - bmpH * 0.38;
      // Plate background
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(plateCx, plateCy), width: plateW, height: plateH),
          Radius.circular(plateH * 0.18),
        ),
        Paint()..color = const Color(0xFFFFF176),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(plateCx, plateCy), width: plateW, height: plateH),
          Radius.circular(plateH * 0.18),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF888800),
      );
      // Plate text
      final tp = TextPainter(
        text: TextSpan(
          text: 'UNREGISTERED',
          style: TextStyle(
            color: const Color(0xFF333300),
            fontSize: plateH * 0.46,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(plateCx - tp.width / 2, plateCy - tp.height / 2));
    }

    // ── Body panel ───────────────────────────────────────────────────────────
    canvas.drawPath(
      trap(yBmp, wBmp, yBod, wBod),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(bodyColor, Colors.white, 0.22)!,
            bodyColor,
          ],
        ).createShader(
            Rect.fromLTRB(cx - wBmp / 2, yBmp, cx + wBmp / 2, yBod)),
    );
    canvas.drawPath(
      trap(yBmp, wBmp, yBod, wBod),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawLine(
      Offset(cx - wBod / 2, yBod),
      Offset(cx + wBod / 2, yBod),
      Paint()
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.38)
        ..strokeCap = StrokeCap.round,
    );
    final dLine = cx + carW * 0.04;
    canvas.drawLine(
      Offset(dLine, yBmp + bdH * 0.06),
      Offset(dLine, yBod - bdH * 0.06),
      Paint()
        ..strokeWidth = 0.9
        ..color = Colors.black.withValues(alpha: 0.22),
    );

    // ── Checker stripe (taxi) ────────────────────────────────────────────────
    if (!isPolice) {
      final sY1 = yBmp - bdH * 0.74;
      final sY2 = yBmp - bdH * 0.30;
      final sh = sY2 - sY1;
      final sw = carW * 0.058;
      for (var col = 0; col < 4; col++) {
        for (var row = 0; row < 2; row++) {
          if ((col + row).isEven) {
            canvas.drawRect(
              Rect.fromLTWH(
                  cx - wBod / 2 + 5 + col * sw, sY1 + row * sh / 2, sw, sh / 2),
              Paint()..color = const Color(0xFF151515),
            );
            canvas.drawRect(
              Rect.fromLTWH(cx + wBod / 2 - 5 - (col + 1) * sw,
                  sY1 + row * sh / 2, sw, sh / 2),
              Paint()..color = const Color(0xFF151515),
            );
          }
        }
      }
    }

    // ── Police door stripe ───────────────────────────────────────────────────
    if (isPolice) {
      final sY1 = yBmp - bdH * 0.72;
      final sY2 = yBmp - bdH * 0.30;
      canvas.drawRect(
        Rect.fromLTRB(cx - wBod / 2 + 3, sY1, cx + wBod / 2 - 3, sY2),
        Paint()..color = const Color(0xFF1565C0).withValues(alpha: 0.55),
      );
      canvas.drawRect(
        Rect.fromLTRB(cx - wBod / 2 + 3, sY1 - bdH * 0.07,
            cx + wBod / 2 - 3, sY1),
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
    }

    // ── Headlights ────────────────────────────────────────────────────────────
    // Pulse: fast strobe-like sine, stays at least dim so shape is always visible
    final hlFlash =
        (math.sin(roadPhase * math.pi * 6) * 0.42 + 0.58).clamp(0.2, 1.0);

    final hlR = carW * 0.052;
    final hlY = yBmp - bdH * 0.22;
    final lensColor = Color.lerp(
      const Color(0xFF554400),   // dim amber
      const Color(0xFFFFEE00),   // bright yellow
      hlFlash,
    )!;
    for (final sign in [-1.0, 1.0]) {
      final hlX = cx + sign * wBod * 0.292;

      if (isPolice) {
        // Police: circular headlights with dark housing
        canvas.drawCircle(
          Offset(hlX, hlY), hlR * 2.20,
          Paint()
            ..color = const Color(0xFFFFDD00).withValues(alpha: hlFlash * 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        canvas.drawCircle(Offset(hlX, hlY), hlR * 1.40,
            Paint()..color = const Color(0xFF060612));
        canvas.drawCircle(Offset(hlX, hlY), hlR * 1.05,
            Paint()..color = lensColor);
        canvas.drawCircle(
          Offset(hlX, hlY), hlR * 0.70,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hlR * 0.22
            ..color = Colors.white.withValues(alpha: hlFlash * 0.55),
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(hlX - hlR * 0.22, hlY - hlR * 0.22),
              width: hlR * 0.55,
              height: hlR * 0.35),
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          Offset(hlX, hlY), hlR * 1.40,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = Colors.black.withValues(alpha: 0.50),
        );
      } else {
        // Taxi: horizontal LED strip headlights — no floating circles
        final stripW = hlR * 3.8;
        final stripH = hlR * 0.62;
        // Subtle glow
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(hlX, hlY),
                width: stripW + 8,
                height: stripH + 6),
            Radius.circular(stripH),
          ),
          Paint()
            ..color = const Color(0xFFFFEE00).withValues(alpha: hlFlash * 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        // Dark housing slot
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(hlX, hlY),
                width: stripW + 2,
                height: stripH + 2),
            Radius.circular(stripH * 0.6),
          ),
          Paint()..color = const Color(0xFF0A0A12),
        );
        // Bright strip
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(hlX, hlY), width: stripW, height: stripH),
            Radius.circular(stripH * 0.5),
          ),
          Paint()..color = lensColor,
        );
        // Specular line
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(hlX, hlY - stripH * 0.18),
                width: stripW * 0.55,
                height: stripH * 0.22),
            Radius.circular(stripH * 0.2),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.45),
        );
      }
    }

    // ── DRL strips ────────────────────────────────────────────────────────────
    final drlY = yBmp - bdH * 0.055;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + sign * wBmp * 0.32, drlY),
              width: carW * 0.090,
              height: carW * 0.022),
          Radius.circular(carW * 0.011),
        ),
        Paint()
          ..color = const Color(0xFFFFEE80)
              .withValues(alpha: 0.60 + hlFlash * 0.28),
      );
    }

    // ── Windshield ────────────────────────────────────────────────────────────
    canvas.drawPath(trap(yHood, wWsh, yWshT, wWshT), Paint()..color = glassCol);
    final apW = carW * 0.024;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx + sign * wWsh / 2, yHood)
          ..lineTo(cx + sign * (wWsh / 2 - apW), yHood)
          ..lineTo(cx + sign * (wWshT / 2 - apW * 0.8), yWshT)
          ..lineTo(cx + sign * wWshT / 2, yWshT)
          ..close(),
        Paint()..color = Color.lerp(bodyColor, Colors.black, 0.12)!,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(cx - wWsh * 0.34, yHood - 2)
        ..lineTo(cx - wWsh * 0.06, yHood - 2)
        ..lineTo(cx - wWshT * 0.09, yWshT + 5)
        ..lineTo(cx - wWshT * 0.38, yWshT + 5)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.09),
    );
    canvas.drawPath(
      trap(yHood, wWsh, yWshT, wWshT),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.black.withValues(alpha: 0.40),
    );

    // ── Roof ──────────────────────────────────────────────────────────────────
    canvas.drawPath(
      trap(yWshT, wWshT, yRfT, wRf),
      Paint()..color = roofColor,
    );
    canvas.drawPath(
      trap(yWshT, wWshT, yRfT, wRf),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = Colors.black.withValues(alpha: 0.32),
    );
    canvas.drawLine(
      Offset(cx - wRf * 0.40, yRfT),
      Offset(cx + wRf * 0.40, yRfT),
      Paint()
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.50)
        ..strokeCap = StrokeCap.round,
    );

    // ── Police lightbar (red/blue strobe, no background bloom) ───────────────
    if (isPolice) {
      final lp    = (sirenPhase + lightOffset) % 1.0;
      final blueA = _sirenAlpha(true,  lp);
      final redA  = _sirenAlpha(false, lp);
      final isBlue = blueA >= redA;
      final flash  = isBlue ? blueA : redA;

      final barCy = yRfT - carW * 0.046;
      final barW2 = wRf * 0.76;
      final barH2 = carW * 0.074;

      // Bar housing
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, barCy), width: barW2, height: barH2),
          Radius.circular(barH2 * 0.42),
        ),
        Paint()..color = const Color(0xFF0A0A14),
      );

      // Blue dome — left
      final blueCol = Color.lerp(
          const Color(0xFF1A2240), const Color(0xFF88CCFF), blueA)!;
      canvas.drawCircle(Offset(cx - barW2 * 0.25, barCy), carW * 0.030,
          Paint()..color = blueCol);
      if (blueA > 0.05) {
        canvas.drawCircle(
          Offset(cx - barW2 * 0.25, barCy), carW * 0.072,
          Paint()
            ..color =
                const Color(0xFF3366FF).withValues(alpha: blueA * 0.60)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Light cone upward
        final bx = cx - barW2 * 0.25;
        canvas.drawPath(
          Path()
            ..moveTo(bx - carW * 0.020, barCy)
            ..lineTo(bx - carW * 0.10, barCy - carW * 0.50)
            ..lineTo(bx + carW * 0.10, barCy - carW * 0.50)
            ..lineTo(bx + carW * 0.020, barCy)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFF4488FF).withValues(alpha: blueA * 0.45),
                const Color(0xFF4488FF).withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(
                bx - carW * 0.10, barCy - carW * 0.50, carW * 0.20, carW * 0.50)),
        );
      }

      // Red dome — right
      final redCol = Color.lerp(
          const Color(0xFF401818), const Color(0xFFFF9999), redA)!;
      canvas.drawCircle(Offset(cx + barW2 * 0.25, barCy), carW * 0.030,
          Paint()..color = redCol);
      if (redA > 0.05) {
        canvas.drawCircle(
          Offset(cx + barW2 * 0.25, barCy), carW * 0.072,
          Paint()
            ..color =
                const Color(0xFFFF2233).withValues(alpha: redA * 0.60)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        final rx = cx + barW2 * 0.25;
        canvas.drawPath(
          Path()
            ..moveTo(rx - carW * 0.020, barCy)
            ..lineTo(rx - carW * 0.10, barCy - carW * 0.50)
            ..lineTo(rx + carW * 0.10, barCy - carW * 0.50)
            ..lineTo(rx + carW * 0.020, barCy)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFFF3344).withValues(alpha: redA * 0.45),
                const Color(0xFFFF3344).withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(
                rx - carW * 0.10, barCy - carW * 0.50, carW * 0.20, carW * 0.50)),
        );
      }

      // Centre divider
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(cx, barCy),
            width: barW2 * 0.20,
            height: barH2 * 0.60),
        Paint()..color = const Color(0xFF2A2A3C),
      );

      // Bar outline
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, barCy), width: barW2, height: barH2),
          Radius.circular(barH2 * 0.42),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.18),
      );

      // Overall bar glow halo
      if (flash > 0.05) {
        final glowColor = isBlue
            ? const Color(0xFF4488FF).withValues(alpha: flash * 0.40)
            : const Color(0xFFFF3344).withValues(alpha: flash * 0.40);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, barCy),
                width: barW2 + carW * 0.14,
                height: barH2 + carW * 0.10),
            Radius.circular(barH2 * 0.80),
          ),
          Paint()
            ..color = glowColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
      }
    }

    // ── Taxi roof sign ─────────────────────────────────────────────────────────
    if (!isPolice) {
      final signCy = yRfT - carW * 0.042;
      final signW  = wRf * 0.42;
      final signH  = carW * 0.074;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, signCy), width: signW, height: signH),
          Radius.circular(signH * 0.28),
        ),
        Paint()..color = const Color(0xFFFFD700),
      );
      // TAXI text
      final tp = TextPainter(
        text: TextSpan(
          text: 'TAXI',
          style: TextStyle(
            color: const Color(0xFF1A0800),
            fontSize: signH * 0.62,
            fontWeight: FontWeight.w900,
            letterSpacing: signH * 0.06,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, signCy - tp.height / 2));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, signCy), width: signW, height: signH),
          Radius.circular(signH * 0.28),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFFCC9900).withValues(alpha: 0.60),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Street graffiti title — spray paint on concrete wall
// ─────────────────────────────────────────────────────────────────────────────

class _TitlePainter extends CustomPainter {
  const _TitlePainter();

  @override
  bool shouldRepaint(_TitlePainter _) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rng = math.Random(55);
    const skewX = -0.20; // right-leaning italic (graffiti angle)

    // ── Concrete wall texture (faint scan lines) ──────────────────────────────
    final wallP = Paint()
      ..color = Colors.white.withValues(alpha: 0.014)
      ..strokeWidth = 0.5;
    for (var i = 0; i < h.toInt(); i += 3) {
      canvas.drawLine(Offset(0, i.toDouble()), Offset(w, i.toDouble()), wallP);
    }

    // ── Spray-paint blobs (paint soaked into wall) ────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.48), width: w * 0.94, height: h * 0.88),
      Paint()
        ..color = const Color(0xFF060503)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.38, h * 0.29), width: w * 0.64, height: h * 0.42),
      Paint()
        ..color = const Color(0xFFFFCC00).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.60, h * 0.72), width: w * 0.66, height: h * 0.42),
      Paint()
        ..color = const Color(0xFFFF2200).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );

    // ── Spray-noise overspray dots ────────────────────────────────────────────
    for (var i = 0; i < 130; i++) {
      final r = 0.3 + rng.nextDouble() * 3.8;
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h),
        r,
        Paint()
          ..color = (rng.nextInt(3) == 0
                  ? const Color(0xFFFF2200)
                  : const Color(0xFFFFCC00))
              .withValues(alpha: 0.015 + rng.nextDouble() * 0.065)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
      );
    }

    // ── Paint drip helper ─────────────────────────────────────────────────────
    void drip(double x, double topY, double ht, Color col) {
      final rw = ht * 0.18;
      canvas.drawPath(
        Path()
          ..moveTo(x - rw, topY)
          ..cubicTo(x - rw * 1.4, topY + ht * 0.35,
                    x - rw * 1.4, topY + ht * 0.68, x, topY + ht)
          ..cubicTo(x + rw * 1.4, topY + ht * 0.68,
                    x + rw * 1.4, topY + ht * 0.35, x + rw, topY)
          ..close(),
        Paint()..color = col.withValues(alpha: 0.84),
      );
      canvas.drawCircle(Offset(x, topY + ht), rw * 1.3,
          Paint()..color = col.withValues(alpha: 0.68));
    }

    // ── Spray-word: italic graffiti text with glow, outline, fill, drips ─────
    void sprayWord(
      String txt,
      double cx, double cy, double fz,
      Color fill, Color outline,
      List<double> dripFracs, Color dripCol,
    ) {
      TextPainter pt(Paint? fg, Color? col) => TextPainter(
            text: TextSpan(
              text: txt,
              style: TextStyle(
                fontSize: fz,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: col,
                foreground: fg,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

      final fillTp = pt(null, fill);
      final strokeTp = pt(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fz * 0.10
          ..strokeJoin = StrokeJoin.round
          ..color = outline,
        null,
      );
      final glowTp = pt(
        Paint()
          ..color = fill.withValues(alpha: 0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
        null,
      );
      final shadowTp = pt(null, Colors.black.withValues(alpha: 0.75));

      // Centre compensated for italic skew: visual mid at (cx,cy)
      final ox = cx - fillTp.width / 2 - skewX * fillTp.height / 2;
      final oy = cy - fillTp.height / 2;

      // Drips first (text covers the top of drip)
      for (final frac in dripFracs) {
        final dripHt = 9.0 + rng.nextDouble() * 24;
        drip(ox + fillTp.width * frac, oy + fillTp.height * 0.80, dripHt, dripCol);
      }

      canvas.save();
      canvas.translate(ox, oy);
      canvas.skew(skewX, 0);
      shadowTp.paint(canvas, const Offset(6, 8));
      glowTp.paint(canvas, Offset.zero);
      strokeTp.paint(canvas, Offset.zero);
      fillTp.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // ── TAXI ─────────────────────────────────────────────────────────────────
    sprayWord(
      'TAXI', w * 0.42, h * 0.27, 74,
      const Color(0xFFFFCC00), const Color(0xFF1A0800),
      [0.10, 0.34, 0.62, 0.88], const Color(0xFFFFAA00),
    );

    // ── RUSH ─────────────────────────────────────────────────────────────────
    sprayWord(
      'RUSH', w * 0.56, h * 0.70, 84,
      const Color(0xFFFF2800), Colors.black,
      [0.08, 0.38, 0.72], const Color(0xFFBB1400),
    );

    // ── Lightning bolt between words ──────────────────────────────────────────
    final bolt = Path()
      ..moveTo(w * 0.535, h * 0.435)
      ..lineTo(w * 0.498, h * 0.525)
      ..lineTo(w * 0.527, h * 0.525)
      ..lineTo(w * 0.487, h * 0.620)
      ..lineTo(w * 0.524, h * 0.528)
      ..lineTo(w * 0.494, h * 0.528)
      ..close();
    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(0xFFFFCC00).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(bolt,
        Paint()..color = const Color(0xFFFFEE00).withValues(alpha: 0.85));

    // ── Stencil subtitle ─────────────────────────────────────────────────────
    final subTp = TextPainter(
      text: TextSpan(
        text: '— ESCAPE THE POLICE —',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 3.8,
          color: Colors.white.withValues(alpha: 0.40),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(canvas, Offset((w - subTp.width) / 2, h * 0.875));

    // ── Corner bracket tags (tagger style) ───────────────────────────────────
    const bLen = 10.0;
    final brkP = Paint()
      ..color = const Color(0x77FF2200)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square;
    for (final c in [
      [0.04, 0.06, 1.0, 1.0],
      [0.96, 0.06, -1.0, 1.0],
      [0.04, 0.94, 1.0, -1.0],
      [0.96, 0.94, -1.0, -1.0],
    ]) {
      final bx = w * c[0], by = h * c[1];
      canvas.drawLine(Offset(bx, by), Offset(bx + c[2] * bLen, by), brkP);
      canvas.drawLine(Offset(bx, by), Offset(bx, by + c[3] * bLen), brkP);
    }
  }
}
