import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../utils/iso_utils.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;

  GamePainter(this.engine) : super(repaint: engine);

  static final Map<String, ui.Picture> _mapCache = {};
  static final Map<String, TextPainter> _phraseCache = {};
  static TextPainter? _plusOnePainter;
  static TextPainter? _taxiRoofPainter;

  static TextPainter _getPlusOnePainter() {
    return _plusOnePainter ??= TextPainter(
      text: const TextSpan(
        text: '+1',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Color(0xFFCC0055), offset: Offset(0.5, 0.5))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static TextPainter _getTaxiRoofPainter() {
    return _taxiRoofPainter ??= TextPainter(
      text: const TextSpan(
        text: 'TAXI',
        style: TextStyle(
          color: Colors.black,
          fontSize: 4.6,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }


  // Precomputed sand particle properties (golden-ratio distribution, computed once).
  static final List<double> _sandPhases = List.generate(
    70,
    (i) => (i * 0.6180339887) % 1.0,
  );
  static final List<double> _sandYFracs = List.generate(
    70,
    (i) => (i * 0.3819660113) % 1.0,
  );
  static final List<double> _sandSpeeds = List.generate(
    70,
    (i) => 45.0 + (i * 37.3) % 90.0,
  );
  static final List<double> _sandLens = List.generate(
    70,
    (i) => 15.0 + (i * 23.7) % 55.0,
  );
  static final List<double> _sandThicks = List.generate(
    70,
    (i) => 0.5 + (i * 0.71) % 1.5,
  );
  static final List<double> _sandAlphas = List.generate(
    70,
    (i) => 0.07 + (i * 0.13) % 0.22,
  );
  static final List<double> _sandCycles = List.generate(
    70,
    (i) => (i * 1.618) % (math.pi * 2),
  );

  TextPainter _getPhrasePainter(String phrase) {
    return _phraseCache.putIfAbsent(phrase, () {
      return TextPainter(
        text: TextSpan(
          text: phrase,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: 80);
    });
  }

  // ?�?� Theme helpers ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  String get _themeId => engine.config.id;

  Color _themeRoadColor() {
    switch (_themeId) {
      case 'suburbs':
        return const Color(0xFF4A4540); // Korean cobblestone
      case 'highway':
        return const Color(0xFFAA8F60); // desert sand road
      case 'night_city':
        return const Color(0xFF0B141E); // wet dark tarmac
      default:
        return const Color(0xFF1F2A33); // modern asphalt
    }
  }

  Color _themeRoadLineColor() {
    switch (_themeId) {
      case 'suburbs':
        return const Color(0xFFD4C4A0); // faint stone marking
      case 'highway':
        return const Color(0xFFEDD28A); // sand dune yellow
      case 'night_city':
        return const Color(0xFF00E5FF); // neon cyan
      default:
        return const Color(0xFFFFD166); // bright yellow
    }
  }

  Color _themeSidewalkColor() {
    switch (_themeId) {
      case 'suburbs':
        return const Color(0xFFBBAA88); // Korean stone tiles
      case 'highway':
        return const Color(0xFFC8A87A); // sandstone
      case 'night_city':
        return const Color(0xFF161B27); // dark concrete
      default:
        return const Color(0xFF5E727D); // gray concrete
    }
  }

  Color _themeParkGroundColor() {
    switch (_themeId) {
      case 'suburbs':
        return const Color(0xFF3D6E3A); // Korean garden green
      case 'highway':
        return const Color(0xFFE2C97A); // desert sand
      case 'night_city':
        return const Color(0xFF0B1F35); // dark plaza
      default:
        return const Color(0xFF227A55); // city park green
    }
  }

  List<Color> _themeBuildingPalette() {
    switch (_themeId) {
      case 'suburbs': // Korean traditional hanok warm tones
        return const [
          Color(0xFFF5ECD7),
          Color(0xFFE8D5B0),
          Color(0xFFD4C49A),
          Color(0xFFF0E6CC),
          Color(0xFFE2CFA8),
          Color(0xFFCDBB90),
        ];
      case 'highway':
        return const [
          Color(0xFFD4A96A),
          Color(0xFFC4955A),
          Color(0xFFB5804A),
          Color(0xFFE2C99A),
          Color(0xFFAA7714),
          Color(0xFFCD9B5A),
        ];
      case 'night_city':
        return const [
          Color(0xFF0D1B2A),
          Color(0xFF1A1A2E),
          Color(0xFF16213E),
          Color(0xFF0F3460),
          Color(0xFF1B1B2F),
          Color(0xFF222244),
        ];
      default: // downtown ??modern glass city
        return buildingPalette;
    }
  }

  Color _themeBuildingColor(int col, int row) {
    final palette = _themeBuildingPalette();
    return palette[(col * 3 + row * 7) % palette.length];
  }

  double _themeBuildingHeight(int col, int row) {
    switch (_themeId) {
      case 'downtown':
        return ((col * 17 + row * 31) % 4 + 1) * 20.0; // 20??0 glass towers
      case 'suburbs':
        return ((col * 17 + row * 31) % 2 + 1) * 16.0; // 16??2 hanok is low
      case 'highway':
        return ((col * 17 + row * 31) % 2 + 1) * 18.0; // 18??6 sandstone
      case 'night_city':
        return ((col * 17 + row * 31) % 3 + 2) * 22.0; // 44??8 cyberpunk
      default:
        return ((col * 17 + row * 31) % 4 + 1) * 20.0;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridW = engine.config.gridWidth;
    final gridH = engine.config.gridHeight;
    final layout = engine.mapLayout;

    canvas.save();
    // Pixel-perfect alignment: rounding the camera offset to the nearest integer
    // pixel eliminates sub-pixel anti-aliasing shimmer on tile edges.
    canvas.translate(
      engine.cameraOffset.dx.roundToDouble(),
      engine.cameraOffset.dy.roundToDouble(),
    );

    canvas.drawPicture(_staticMapPicture(gridW, gridH, layout));

    // Police detection radars (drawn under entities)
    for (final police in engine.policeUnits) {
      _drawPoliceRadar(canvas, police);
    }

    // Destination markers for passengers being carried
    for (final p in engine.passengers) {
      if (p.state == PassengerState.inTaxi) {
        final pos = isoOffset(p.destination.x, p.destination.y);
        _drawDestinationMarker(canvas, pos, p.color);
      }
    }

    // Destination markers for waiting passengers
    for (final p in engine.passengers) {
      if (p.state == PassengerState.waiting) {
        final pos = isoOffset(p.destination.x, p.destination.y);
        _drawDestinationMarker(canvas, pos, p.color);
      }
    }

    // Sort entities by depth for correct overlap
    final entities = <_Entity>[];

    for (final p in engine.passengers) {
      if (p.state == PassengerState.waiting) {
        entities.add(
          _Entity(
            depth: p.gridPos.x + p.gridPos.y,
            draw: (c) => _drawPassenger(c, p),
          ),
        );
      }
    }

    for (final police in engine.policeUnits) {
      final gx = police.pos.x;
      final gy = police.pos.y;
      entities.add(
        _Entity(depth: gx + gy + 0.5, draw: (c) => _drawPolice(c, police)),
      );
    }

    for (final pickup in engine.lifePickups) {
      entities.add(
        _Entity(
          depth: pickup.gridPos.x + pickup.gridPos.y + 0.2,
          draw: (c) => _drawLifePickup(c, pickup),
        ),
      );
    }

    for (final b in engine.bullets) {
      entities.add(
        _Entity(depth: b.pos.x + b.pos.y + 0.3, draw: (c) => _drawBullet(c, b)),
      );
    }

    // Taxi
    final taxiGx = engine.taxiPos.x;
    final taxiGy = engine.taxiPos.y;
    entities.add(
      _Entity(depth: taxiGx + taxiGy + 0.5, draw: (c) => _drawTaxi(c)),
    );

    entities.sort((a, b) => a.depth.compareTo(b.depth));
    for (final e in entities) {
      e.draw(canvas);
    }

    _drawOccludingBuildings(canvas);

    canvas.restore();

    _drawSandWindEffect(canvas, size);
  }

  // Re-draws building tiles that visually sit in front of any moving entity
  // at reduced opacity so the player can see entities behind buildings.
  void _drawOccludingBuildings(Canvas canvas) {
    final layout = engine.mapLayout;
    final gridW = engine.config.gridWidth;
    final gridH = engine.config.gridHeight;
    // radius=1 → 3×3 area maximum; was 2 (5×5). Reduces saveLayer count significantly.
    const radius = 1;

    final checks = <(double x, double y, double depth)>[
      (engine.taxiPos.x, engine.taxiPos.y, engine.taxiPos.x + engine.taxiPos.y),
    ];

    final drawn = <int>{};

    for (final (ex, ey, eDepth) in checks) {
      final c0 = math.max(0, ex.floor() - radius);
      final c1 = math.min(gridW - 1, ex.ceil() + radius);
      final r0 = math.max(0, ey.floor() - radius);
      final r1 = math.min(gridH - 1, ey.ceil() + radius);

      for (int row = r0; row <= r1; row++) {
        for (int col = c0; col <= c1; col++) {
          if (layout[row][col] != TileType.building.index) continue;
          if (col + row <= eDepth) continue;
          final key = col * 10000 + row;
          if (!drawn.add(key)) continue;

          final pos = isoOffset(col.toDouble(), row.toDouble());
          final bh = _themeBuildingHeight(col, row);

          // Bounded saveLayer: limits the offscreen buffer to the tile's pixel
          // area instead of allocating a full-screen buffer (was saveLayer(null)).
          // kTileW=64, kTileH=32 — extend upward by building height.
          final tileRect = Rect.fromLTRB(
            pos.dx - kTileW / 2 - 2,
            pos.dy - bh - kTileH / 2 - 2,
            pos.dx + kTileW / 2 + 2,
            pos.dy + kTileH / 2 + 2,
          );
          canvas.saveLayer(
            tileRect,
            Paint()..color = Colors.white.withValues(alpha: 0.45),
          );
          _drawBuildingTile(canvas, pos, col, row);
          canvas.restore();
        }
      }
    }
  }

  ui.Picture _staticMapPicture(int gridW, int gridH, List<List<int>> layout) {
    final key = [
      engine.config.id,
      engine.config.gridWidth,
      engine.config.gridHeight,
      engine.config.difficulty,
    ].join('|');
    final cached = _mapCache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final staticCanvas = Canvas(recorder);
    for (int row = 0; row < gridH; row++) {
      for (int col = 0; col < gridW; col++) {
        final tileIdx = layout[row][col];
        final type = TileType.values[tileIdx];
        final pos = isoOffset(col.toDouble(), row.toDouble());
        _drawTile(staticCanvas, pos, type, col, row);
      }
    }

    final picture = recorder.endRecording();
    _mapCache[key] = picture;
    return picture;
  }

  // ?�?� Radar ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawPoliceRadar(Canvas canvas, PoliceUnit police) {
    final cx = police.pos.x;
    final cy = police.pos.y;
    final r = police.detectionRadius + engine.gameState.level * 0.8;

    final north = isoOffset(cx, cy - r);
    final south = isoOffset(cx, cy + r);
    final east = isoOffset(cx + r, cy);
    final west = isoOffset(cx - r, cy);

    final path = Path()
      ..moveTo(north.dx, north.dy)
      ..lineTo(east.dx, east.dy)
      ..lineTo(south.dx, south.dy)
      ..lineTo(west.dx, west.dy)
      ..close();

    final isChasing = police.state == PoliceState.chasing;
    final t = engine.animTime;
    final pulse = (math.sin(t * (isChasing ? 7.0 : 2.0)) + 1) / 2;

    final fillAlpha = isChasing ? 0.06 + pulse * 0.09 : 0.03 + pulse * 0.04;
    final strokeAlpha = isChasing ? 0.5 + pulse * 0.4 : 0.15 + pulse * 0.2;

    final fillColor = isChasing
        ? Colors.red.withValues(alpha: fillAlpha)
        : Colors.blue.withValues(alpha: fillAlpha);
    final strokeColor = isChasing
        ? Colors.red.withValues(alpha: strokeAlpha)
        : Colors.blue.withValues(alpha: strokeAlpha);

    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isChasing ? 2.0 : 1.2,
    );
  }

  // ?�?� Tiles ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawTile(Canvas canvas, Offset pos, TileType type, int col, int row) {
    switch (type) {
      case TileType.road:
        _drawRoadTile(canvas, pos, col, row);
        break;
      case TileType.sidewalk:
        _drawSidewalkTile(canvas, pos);
        break;
      case TileType.building:
        _drawBuildingTile(canvas, pos, col, row);
        break;
      case TileType.park:
        _drawParkTile(canvas, pos, col, row);
        break;
      case TileType.water:
        _drawWaterTile(canvas, pos);
        break;
      case TileType.intersection:
        _drawRoadTile(canvas, pos, col, row);
        break;
    }
  }

  void _drawIsoTileFlat(Canvas canvas, Offset center, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - kTileH / 2)
      ..lineTo(center.dx + kTileW / 2, center.dy)
      ..lineTo(center.dx, center.dy + kTileH / 2)
      ..lineTo(center.dx - kTileW / 2, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.035)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawRoadTile(Canvas canvas, Offset pos, int col, int row) {
    final layout = engine.mapLayout;
    final gridH = engine.config.gridHeight;

    _drawIsoTileFlat(canvas, pos, _themeRoadColor());

    final isHRoad =
        row > 0 && row < gridH - 1 && layout[row][col] == TileType.road.index;

    final linePaint = Paint()
      ..color = _themeRoadLineColor().withValues(alpha: 0.62)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    if (isHRoad) {
      canvas.drawLine(
        Offset(pos.dx - kTileW / 5, pos.dy),
        Offset(pos.dx + kTileW / 5, pos.dy),
        linePaint,
      );
    }
  }

  void _drawSidewalkTile(Canvas canvas, Offset pos) {
    _drawIsoTileFlat(canvas, pos, _themeSidewalkColor());
  }

  void _drawBuildingTile(Canvas canvas, Offset pos, int col, int row) {
    _drawIsoTileFlat(canvas, pos, _themeSidewalkColor());

    final baseColor = _themeBuildingColor(col, row);
    final bh = _themeBuildingHeight(col, row);
    final hw = kTileW / 2;
    final hh = kTileH / 2;

    final shadowPath = Path()
      ..moveTo(pos.dx, pos.dy + hh + 4)
      ..lineTo(pos.dx + hw + 4, pos.dy + 4)
      ..lineTo(pos.dx + hw + 4, pos.dy + hh + 4)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    final rightPath = Path()
      ..moveTo(pos.dx, pos.dy + hh)
      ..lineTo(pos.dx + hw, pos.dy)
      ..lineTo(pos.dx + hw, pos.dy - bh)
      ..lineTo(pos.dx, pos.dy + hh - bh)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = buildingSideColor(baseColor));

    final leftPath = Path()
      ..moveTo(pos.dx, pos.dy + hh)
      ..lineTo(pos.dx - hw, pos.dy)
      ..lineTo(pos.dx - hw, pos.dy - bh)
      ..lineTo(pos.dx, pos.dy + hh - bh)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = buildingFrontColor(baseColor));

    final topPath = Path()
      ..moveTo(pos.dx, pos.dy - bh - hh)
      ..lineTo(pos.dx + hw, pos.dy - bh)
      ..lineTo(pos.dx, pos.dy + hh - bh)
      ..lineTo(pos.dx - hw, pos.dy - bh)
      ..close();
    canvas.drawPath(topPath, Paint()..color = buildingTopColor(baseColor));

    switch (_themeId) {
      case 'suburbs':
        _drawKoreanBuildingDetails(canvas, pos, bh, hw, hh, col, row);
      case 'highway':
        _drawEgyptBuildingDetails(canvas, pos, bh, hw, hh, col, row);
      case 'night_city':
        _drawNightBuildingDetails(canvas, pos, bh, baseColor, hw, hh, col, row);
      default: // downtown: modern glass
        _drawWindows(canvas, pos, bh, baseColor, col, row);
    }

    final outlinePath = Path()
      ..moveTo(pos.dx, pos.dy - bh - hh)
      ..lineTo(pos.dx + hw, pos.dy - bh)
      ..lineTo(pos.dx + hw, pos.dy)
      ..lineTo(pos.dx, pos.dy + hh)
      ..lineTo(pos.dx - hw, pos.dy)
      ..lineTo(pos.dx - hw, pos.dy - bh)
      ..close();
    canvas.drawPath(
      outlinePath,
      Paint()
        ..color = const Color(0xFF0B1118).withValues(alpha: 0.36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawWindows(
    Canvas canvas,
    Offset pos,
    double bh,
    Color baseColor,
    int col,
    int row,
  ) {
    final windowColor = const Color(0xFF8DEBFF).withValues(alpha: 0.68);
    final litColor = const Color(0xFFFFF176).withValues(alpha: 0.88);
    final hw = kTileW / 2;

    final floors = (bh / 16).floor().clamp(1, 4);
    for (int f = 0; f < floors; f++) {
      final fy = pos.dy - bh + f * 16 + 10;

      for (int w = 0; w < 2; w++) {
        final wx = pos.dx + hw * (0.25 + w * 0.4);
        final wy = fy - (w * 4);
        final isLit = ((col + row + f + w) % 3 != 0);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(wx, wy), width: 6, height: 5),
          Paint()..color = isLit ? litColor : windowColor,
        );
      }

      for (int w = 0; w < 2; w++) {
        final wx = pos.dx - hw * (0.25 + w * 0.4);
        final wy = fy - 2 + (w * 4);
        final isLit = ((col + row + f + w + 1) % 3 != 0);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(wx, wy), width: 6, height: 5),
          Paint()..color = isLit ? litColor : windowColor,
        );
      }
    }
  }

  // ?�?� Theme building details ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawKoreanBuildingDetails(
    Canvas canvas,
    Offset pos,
    double bh,
    double hw,
    double hh,
    int col,
    int row,
  ) {
    const roofTile = Color(0xFF2B3A4A); // dark charcoal-blue tiles
    const roofLight = Color(0xFF8BA0A8); // ridge highlight
    const woodColor = Color(0xFF8B3A1A); // red-brown timber

    final roofTopY = pos.dy - bh - hh; // apex
    final roofMidY = pos.dy - bh; // E/W level
    final roofBotY = pos.dy + hh - bh; // south point
    const ov = 7.0; // overhang beyond wall footprint

    // ?�?� Tiled roof face (covers the wall top + overhangs) ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
    final roofFace = Path()
      ..moveTo(pos.dx, roofTopY - ov * 0.6) // north peak
      ..lineTo(pos.dx + hw + ov, roofMidY) // east tip
      ..lineTo(pos.dx, roofBotY + ov * 0.4) // south
      ..lineTo(pos.dx - hw - ov, roofMidY) // west tip
      ..close();
    canvas.drawPath(roofFace, Paint()..color = roofTile);

    // ?�?� Upturned eave tips (east & west) ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
    for (final sign in [-1.0, 1.0]) {
      final tipX = pos.dx + sign * (hw + ov);
      final tipPath = Path()
        ..moveTo(tipX - sign * 4, roofMidY - 1)
        ..quadraticBezierTo(
          tipX + sign * 3,
          roofMidY - 7,
          tipX + sign * 8,
          roofMidY - 3,
        )
        ..lineTo(tipX + sign * 3, roofMidY + 2)
        ..close();
      canvas.drawPath(tipPath, Paint()..color = roofTile);
    }

    // ?�?� Roof ridge (center spine N?�S) ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
    canvas.drawLine(
      Offset(pos.dx, roofTopY - ov * 0.6),
      Offset(pos.dx, roofBotY + ov * 0.3),
      Paint()
        ..color = roofLight
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // ?�?� Roof outline ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
    canvas.drawPath(
      roofFace,
      Paint()
        ..color = const Color(0xFF0B1118).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    // ?�?� Wooden pillars at wall corners ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
    final pillarPaint = Paint()..color = woodColor;
    // right-front pillar
    canvas.drawRect(
      Rect.fromLTWH(pos.dx + hw - 4, pos.dy - bh, 3, bh),
      pillarPaint,
    );
    // left-front pillar
    canvas.drawRect(
      Rect.fromLTWH(pos.dx - hw + 1, pos.dy - bh, 3, bh),
      pillarPaint,
    );

    // ?�?� Hanji (paper screen) windows on the left (front) face ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
    final wCount = (bh / 22).floor().clamp(1, 2);
    for (int f = 0; f < wCount; f++) {
      final wy = pos.dy - bh * 0.65 + f * 18;
      final wx = pos.dx - hw * 0.42;
      // Window body
      canvas.drawRect(
        Rect.fromCenter(center: Offset(wx, wy), width: 9, height: 8),
        Paint()..color = const Color(0xFFF8F0DC).withValues(alpha: 0.88),
      );
      // Frame
      canvas.drawRect(
        Rect.fromCenter(center: Offset(wx, wy), width: 9, height: 8),
        Paint()
          ..color = woodColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
      // Hanji grid lines
      canvas.drawLine(
        Offset(wx - 4.5, wy),
        Offset(wx + 4.5, wy),
        Paint()
          ..color = woodColor.withValues(alpha: 0.4)
          ..strokeWidth = 0.5,
      );
      canvas.drawLine(
        Offset(wx, wy - 4),
        Offset(wx, wy + 4),
        Paint()
          ..color = woodColor.withValues(alpha: 0.4)
          ..strokeWidth = 0.5,
      );
    }
  }

  void _drawEgyptBuildingDetails(
    Canvas canvas,
    Offset pos,
    double bh,
    double hw,
    double hh,
    int col,
    int row,
  ) {
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.14)
      ..strokeWidth = 0.8;
    final courses = (bh / 12).floor().clamp(1, 5);
    for (int i = 1; i < courses; i++) {
      final frac = i / courses;
      final y = pos.dy + hh - bh + bh * frac;
      canvas.drawLine(
        Offset(pos.dx, y),
        Offset(pos.dx + hw, y - hh),
        linePaint,
      );
      canvas.drawLine(
        Offset(pos.dx, y),
        Offset(pos.dx - hw, y - hh),
        linePaint,
      );
    }
    // Cornice strip at top
    final corniceR = Paint()..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawPath(
      Path()
        ..moveTo(pos.dx, pos.dy - bh - hh + 5)
        ..lineTo(pos.dx + hw, pos.dy - bh + 5)
        ..lineTo(pos.dx + hw, pos.dy - bh + 9)
        ..lineTo(pos.dx, pos.dy - bh - hh + 9)
        ..close(),
      corniceR,
    );
    // Sparse hieroglyph dots
    final dotPaint = Paint()..color = Colors.black.withValues(alpha: 0.18);
    final hash = col * 5 + row * 3;
    for (int d = 0; d < 3; d++) {
      final dx = pos.dx - hw * 0.5 + d * hw * 0.45;
      final dy = pos.dy + hh - bh * 0.55 + (hash + d * 7) % 8 * 2.0;
      canvas.drawCircle(Offset(dx, dy), 1.4, dotPaint);
    }
  }

  void _drawNightBuildingDetails(
    Canvas canvas,
    Offset pos,
    double bh,
    Color baseColor,
    double hw,
    double hh,
    int col,
    int row,
  ) {
    const neons = [
      Color(0xFF00E5FF),
      Color(0xFFFF00FF),
      Color(0xFFFFFF00),
      Color(0xFF00FF88),
      Color(0xFFFF4081),
    ];
    final neon = neons[(col + row) % neons.length];
    final neonPaint = Paint()
      ..color = neon.withValues(alpha: 0.75)
      ..strokeWidth = 1.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Horizontal neon strips on right face
    final strips = (bh / 22).floor().clamp(1, 5);
    for (int i = 1; i <= strips; i++) {
      final y = pos.dy + hh - bh + bh * i / (strips + 1);
      canvas.drawLine(
        Offset(pos.dx, y),
        Offset(pos.dx + hw, y - hh),
        neonPaint,
      );
    }
    // Neon glowing windows
    final winPaint = Paint()
      ..color = neon.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final floors = (bh / 16).floor().clamp(1, 5);
    for (int f = 0; f < floors; f++) {
      final fy = pos.dy - bh + f * 16 + 10;
      for (int w = 0; w < 2; w++) {
        final wx = pos.dx + hw * (0.25 + w * 0.4);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(wx, fy - w * 4), width: 6, height: 5),
          winPaint,
        );
      }
      for (int w = 0; w < 2; w++) {
        final wx = pos.dx - hw * (0.25 + w * 0.4);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(wx, fy - 2 + w * 4),
            width: 6,
            height: 5,
          ),
          winPaint,
        );
      }
    }
    // Rooftop antenna
    final antennaTop = Offset(pos.dx, pos.dy - bh - hh - 14);
    canvas.drawLine(
      Offset(pos.dx, pos.dy - bh - hh),
      antennaTop,
      Paint()
        ..color = const Color(0xFF90A4AE)
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      antennaTop,
      2.5,
      Paint()
        ..color = neon
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  // ?�?� Park tiles ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawParkTile(Canvas canvas, Offset pos, int col, int row) {
    _drawIsoTileFlat(canvas, pos, _themeParkGroundColor());
    switch (_themeId) {
      case 'highway':
        _drawPalmTree(canvas, pos, col, row);
      case 'night_city':
        _drawNeonStreetLight(canvas, pos, col, row);
      default: // downtown + suburbs both get regular trees
        _drawRegularTree(canvas, pos, col, row);
    }
  }

  void _drawRegularTree(Canvas canvas, Offset pos, int col, int row) {
    final treeX = pos.dx + ((col * 7 + row * 13) % 10 - 5).toDouble() * 2;
    final treeY = pos.dy - 4;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(treeX, treeY + 4), width: 3, height: 8),
      Paint()..color = const Color(0xFF5D4037),
    );
    final canopyPaint = Paint()..color = const Color(0xFF1FAA63);
    canvas.drawCircle(Offset(treeX, treeY - 6), 10, canopyPaint);
    canvas.drawCircle(Offset(treeX - 5, treeY - 3), 7, canopyPaint);
    canvas.drawCircle(Offset(treeX + 5, treeY - 3), 7, canopyPaint);
    canvas.drawCircle(
      Offset(treeX - 2, treeY - 8),
      4,
      Paint()..color = const Color(0xFF43A047).withValues(alpha: 0.6),
    );
  }

  void _drawPalmTree(Canvas canvas, Offset pos, int col, int row) {
    final treeX = pos.dx + ((col * 7 + row * 13) % 10 - 5).toDouble() * 1.5;
    final treeY = pos.dy - 4;
    // Curved trunk
    canvas.drawPath(
      Path()
        ..moveTo(treeX, treeY + 8)
        ..quadraticBezierTo(treeX + 4, treeY - 2, treeX, treeY - 14),
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Fronds
    final frondPaint = Paint()
      ..color = const Color(0xFF558B2F)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final f in [
      [-13.0, -5.0],
      [13.0, -5.0],
      [-8.0, -15.0],
      [8.0, -15.0],
      [0.0, -20.0],
      [-10.0, -11.0],
      [10.0, -11.0],
    ]) {
      canvas.drawLine(
        Offset(treeX, treeY - 14),
        Offset(treeX + f[0], treeY + f[1]),
        frondPaint,
      );
    }
    canvas.drawCircle(
      Offset(treeX, treeY - 14),
      2.5,
      Paint()..color = const Color(0xFF33691E),
    );
  }

  void _drawNeonStreetLight(Canvas canvas, Offset pos, int col, int row) {
    const neons = [Color(0xFF00E5FF), Color(0xFFFF00FF), Color(0xFF00FF88)];
    final neon = neons[(col + row * 2) % neons.length];
    final cx = pos.dx;
    final cy = pos.dy - 4;
    canvas.drawLine(
      Offset(cx, cy + 8),
      Offset(cx, cy - 10),
      Paint()
        ..color = const Color(0xFF90A4AE)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(cx, cy - 13),
      6,
      Paint()
        ..color = neon
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      Offset(cx, cy - 13),
      3,
      Paint()
        ..color = neon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawWaterTile(Canvas canvas, Offset pos) {
    _drawIsoTileFlat(canvas, pos, const Color(0xFF0E5EA8));
    final wavePaint = Paint()
      ..color = const Color(0xFFB3E5FC).withValues(alpha: 0.34)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(pos.dx - 12, pos.dy - 2),
      Offset(pos.dx + 4, pos.dy - 2),
      wavePaint,
    );
    canvas.drawLine(
      Offset(pos.dx - 4, pos.dy + 2),
      Offset(pos.dx + 12, pos.dy + 2),
      wavePaint,
    );
  }

  // ?�?� Destination marker ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawDestinationMarker(Canvas canvas, Offset pos, Color color) {
    final t = engine.animTime;
    final bounce = math.sin(t * 3.0) * 4;
    final markerPos = Offset(pos.dx, pos.dy - 16 - bounce);
    final pulse = 0.65 + 0.35 * math.sin(t * 4.0).abs();

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.22 + pulse * 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy), width: 40, height: 20),
      ringPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy),
        width: 28 + pulse * 10,
        height: 14 + pulse * 5,
      ),
      Paint()..color = color.withValues(alpha: 0.08),
    );

    canvas.drawLine(
      Offset(markerPos.dx, markerPos.dy + 16),
      Offset(markerPos.dx, markerPos.dy + 26),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 2,
    );

    final flagPath = Path()
      ..moveTo(markerPos.dx, markerPos.dy)
      ..lineTo(markerPos.dx + 14, markerPos.dy + 5)
      ..lineTo(markerPos.dx, markerPos.dy + 10)
      ..close();
    canvas.drawPath(flagPath, Paint()..color = color);
    canvas.drawPath(
      flagPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _drawStar(canvas, Offset(markerPos.dx, markerPos.dy - 8), 6, color);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
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
    canvas.drawPath(path, Paint()..color = color);
  }

  // ?�?� Passenger ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawPassenger(Canvas canvas, Passenger p) {
    final pos = isoOffset(p.gridPos.x, p.gridPos.y);
    final t = engine.animTime;

    // Stable hash for consistent per-passenger variety
    final hash = (p.gridPos.x * 7 + p.gridPos.y * 13).toInt().abs();

    const skinTones = [
      Color(0xFFF5CBA7), // light
      Color(0xFFD4956A), // tan
      Color(0xFFC17843), // medium brown
      Color(0xFF8D5524), // dark brown
    ];
    const hairColors = [
      Color(0xFF1A1A1A), // black
      Color(0xFF5D4037), // brown
      Color(0xFFB8860B), // dark gold
      Color(0xFFBDBDBD), // grey
      Color(0xFF4A148C), // dark purple
    ];
    final skinColor = skinTones[hash % 4];
    final hairColor = hairColors[hash % 5];

    // All vertical positions are relative to groundY ??feet are always planted.
    final gY = pos.dy; // ground level

    // Shadow (fixed to ground)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, gY + 2), width: 22, height: 9),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // Shoes
    final shoePaint = Paint()..color = const Color(0xFF263238);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx - 4, gY), width: 7, height: 3),
      shoePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx + 4, gY), width: 7, height: 3),
      shoePaint,
    );

    // Legs (attached to ground)
    final legColor = Color.lerp(p.color, Colors.black, 0.45)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pos.dx - 5, gY - 11, 4, 11),
        const Radius.circular(2),
      ),
      Paint()..color = legColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pos.dx + 1, gY - 11, 4, 11),
        const Radius.circular(2),
      ),
      Paint()..color = legColor,
    );

    // Body (sits directly on top of legs)
    const bodyH = 14.0;
    final bodyCenter = Offset(pos.dx, gY - 11 - bodyH / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: bodyCenter, width: 14, height: bodyH),
        const Radius.circular(3),
      ),
      Paint()..color = p.color,
    );
    // Collar highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pos.dx, bodyCenter.dy - bodyH / 2 + 2),
          width: 8,
          height: 3,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    // Arms ??only the raised waving arm animates; body stays still
    final armWave = math.sin(t * 4.0 + p.gridPos.x * 1.3) * 5.0;
    final shoulderY = bodyCenter.dy - bodyH / 2 + 3;
    final armPaint = Paint()
      ..color = skinColor
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    // Waving arm (right)
    canvas.drawLine(
      Offset(pos.dx + 7, shoulderY),
      Offset(pos.dx + 13, shoulderY - 8 + armWave),
      armPaint,
    );
    // Resting arm (left, slight droop)
    canvas.drawLine(
      Offset(pos.dx - 7, shoulderY),
      Offset(pos.dx - 11, shoulderY + 4),
      armPaint,
    );

    // Head (sits directly above body)
    const headR = 6.0;
    final headCenter = Offset(pos.dx, bodyCenter.dy - bodyH / 2 - headR);
    canvas.drawCircle(headCenter, headR, Paint()..color = skinColor);

    // Hair
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          headCenter.dx - headR,
          headCenter.dy - headR,
          headR * 2,
          5,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = hairColor,
    );

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(
      Offset(headCenter.dx - 2.2, headCenter.dy - 0.5),
      1.1,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + 2.2, headCenter.dy - 0.5),
      1.1,
      eyePaint,
    );
    // Mouth (tiny curve suggesting expression)
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx, headCenter.dy + 1.5),
        width: 5,
        height: 3,
      ),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF5D1A00).withValues(alpha: 0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // ?�?� Speech bubble ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
    final bubblePulse = (math.sin(t * 1.8 + p.gridPos.y) + 1) / 2;
    final bubbleBaseY = headCenter.dy - headR - 10 - bubblePulse * 2;

    final tp = _getPhrasePainter(p.hailPhrase);

    final bw = tp.width + 10;
    final bh = tp.height + 7;
    final bx = pos.dx - bw / 2;
    final bubbleTop = bubbleBaseY - bh;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, bubbleTop, bw, bh),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, bubbleTop, bw, bh),
        const Radius.circular(5),
      ),
      Paint()
        ..color = p.color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Tail pointing down toward head
    final tailPath = Path()
      ..moveTo(pos.dx - 4, bubbleBaseY)
      ..lineTo(pos.dx + 4, bubbleBaseY)
      ..lineTo(pos.dx, bubbleBaseY + 5)
      ..close();
    canvas.drawPath(
      tailPath,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = p.color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    tp.paint(canvas, Offset(bx + 5, bubbleTop + 3));
  }

  // ?�?� Life pickup ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawLifePickup(Canvas canvas, LifePickup pickup) {
    final pos = isoOffset(pickup.gridPos.x, pickup.gridPos.y);
    final t = engine.animTime;
    final pulse = 0.85 + 0.15 * math.sin(t * 3.0).abs();
    final bounce = math.sin(t * 2.5) * 3;
    final cx = pos.dx;
    final cy = pos.dy - 14 - bounce;
    final r = 7.0 * pulse;

    // Glow (plain circle ??no blur to keep it cheap per-frame)
    canvas.drawCircle(
      Offset(cx, cy),
      r * 2.2,
      Paint()..color = const Color(0xFFFF4081).withValues(alpha: 0.18),
    );

    // Heart: two circles + bottom triangle
    final heartPaint = Paint()..color = const Color(0xFFFF4081);
    canvas.drawCircle(
      Offset(cx - r * 0.5, cy - r * 0.15),
      r * 0.65,
      heartPaint,
    );
    canvas.drawCircle(
      Offset(cx + r * 0.5, cy - r * 0.15),
      r * 0.65,
      heartPaint,
    );
    final heartPath = Path()
      ..moveTo(cx - r, cy)
      ..lineTo(cx, cy + r * 1.2)
      ..lineTo(cx + r, cy)
      ..close();
    canvas.drawPath(heartPath, heartPaint);

    // Shine
    canvas.drawCircle(
      Offset(cx - r * 0.3, cy - r * 0.35),
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    // "+1" label
    final tp = _getPlusOnePainter();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + r * 1.3));
  }

  // ?�?� Bullet ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawBullet(Canvas canvas, Bullet b) {
    final pos = isoOffset(b.pos.x, b.pos.y);
    final glowColor = b.fromTaxi
        ? const Color(0xFF29B6F6)
        : const Color(0xFFFFD600);
    final coreColor = b.fromTaxi
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFFD600);

    final trailIsoX = (b.vel.x - b.vel.y) * 32;
    final trailIsoY = (b.vel.x + b.vel.y) * 16;
    final trailLen = math.sqrt(trailIsoX * trailIsoX + trailIsoY * trailIsoY);

    if (trailLen > 0) {
      final nx = -trailIsoX / trailLen;
      final ny = -trailIsoY / trailLen;
      const len = 22.0;
      final tailEnd = Offset(pos.dx + nx * len, pos.dy + ny * len);

      canvas.drawLine(
        pos,
        tailEnd,
        Paint()
          ..color = glowColor.withValues(alpha: 0.35)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        pos,
        Offset(pos.dx + nx * len * 0.6, pos.dy + ny * len * 0.6),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.88)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      pos,
      5,
      Paint()..color = glowColor.withValues(alpha: 0.28),
    );
    canvas.drawCircle(pos, 3.2, Paint()..color = coreColor);
    canvas.drawCircle(pos, 1.5, Paint()..color = Colors.white);
  }

  // ?�?� Police ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawPolice(Canvas canvas, PoliceUnit police) {
    final pos = isoOffset(police.pos.x, police.pos.y);
    final isChasing = police.state == PoliceState.chasing;
    final t = engine.animTime;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy + 4),
        width: 30,
        height: 12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // Muzzle flash when a bullet was just fired
    if (police.muzzleFlashTimer > 0) {
      final flashAlpha = (police.muzzleFlashTimer / 0.18).clamp(0.0, 1.0);
      canvas.drawCircle(
        pos,
        14,
        Paint()
          ..color = const Color(0xFFFFF59D).withValues(alpha: flashAlpha * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    _drawCar(
      canvas,
      pos,
      const Color(0xFFFFFFFF), // white police body
      const Color(0xFF000000), // black accent
      isPolice: true,
      animTime: t,
      isChasing: isChasing,
      facing: police.facing,
      gridHeading: police.heading,
    );

    // ── Stun smoke — shown when police is stunned by shotgun ──────────────────
    if (police.state == PoliceState.stunned) {
      final stunFrac = (police.stunTimer / 3.0).clamp(0.0, 1.0);
      // 4 smoke puffs cycling upward at different phases
      for (var i = 0; i < 4; i++) {
        final phase = (t * 1.2 + i * 0.55) % 2.0;
        final rise  = phase * 14.0;
        final fade  = ((1.0 - phase / 2.0) * stunFrac).clamp(0.0, 1.0);
        final rx    = math.sin(i * 2.4 + t) * 7.0;
        canvas.drawCircle(
          Offset(pos.dx + rx, pos.dy - rise - 8),
          4.5 + phase * 2.5,
          Paint()
            ..color = const Color(0xFFAAAAAA).withValues(alpha: 0.60 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      // Animated "★" star glow above car
      final starBob = math.sin(t * 6) * 2;
      canvas.drawCircle(
        Offset(pos.dx, pos.dy - 30 + starBob),
        8,
        Paint()
          ..color = const Color(0xFFFFD600).withValues(alpha: 0.75 * stunFrac)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(pos.dx, pos.dy - 30 + starBob),
        4,
        Paint()..color = const Color(0xFFFFFF99).withValues(alpha: stunFrac),
      );
    }
  }

  // ?�?� Taxi ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawTaxi(Canvas canvas) {
    final pos = isoOffset(engine.taxiPos.x, engine.taxiPos.y);
    final jumpH = engine.taxiJumpHeight;
    final airPos = Offset(pos.dx, pos.dy - jumpH); // lifted position
    final isInvis = engine.isInvisible;
    final seatScale = 1.0 + engine.seatUpgrades * 0.10;

    // Ghost effect when invisible
    if (isInvis) {
      canvas.saveLayer(
        null,
        Paint()..color = const Color(0xFF80CCFF).withValues(alpha: 0.38),
      );
    }

    // Shadow stays on the ground and shrinks as the car rises.
    final shadowScale = (1.0 - jumpH / 90.0).clamp(0.25, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy + 4),
        width: 34 * seatScale * shadowScale,
        height: 13 * shadowScale,
      ),
      Paint()..color = Colors.black.withValues(alpha: (isInvis ? 0.1 : 0.3) * shadowScale),
    );

    // Scale the car body for seat upgrades, pivoting around the lifted position.
    canvas.save();
    canvas.translate(airPos.dx, airPos.dy);
    canvas.scale(seatScale);
    canvas.translate(-airPos.dx, -airPos.dy);

    // Collect in-taxi passenger colours (max 4 for window drawing)
    final inTaxi = engine.passengers
        .where((p) => p.state == PassengerState.inTaxi)
        .take(4)
        .toList();

    _drawCar(
      canvas,
      airPos,
      const Color(0xFFFFD600),
      const Color(0xFFE65100),
      isPolice: false,
      animTime: engine.animTime,
      isChasing: false,
      facing: engine.taxiDirection,
      // Use the smoothly interpolated visual heading so the sprite rotates
      // gradually when turning instead of snapping.
      gridHeading: engine.taxiVisualHeading,
      isBoosting: engine.isBoosting,
      hasGun: engine.gunAmmo > 0,
      drawGroundShadow: false,
      passengerColors: inTaxi.map((p) => p.color).toList(),
    );

    canvas.restore();

    if (isInvis) canvas.restore();
  }

  // Car body — rendered as a 3-face isometric box using proper grid-aligned projection.
  // fwd/lat coords are in grid units; height is in screen pixels (vertical lift only).
  void _drawCar(
    Canvas canvas,
    Offset pos,
    Color bodyColor,
    Color accentColor, {
    required bool isPolice,
    required double animTime,
    required bool isChasing,
    required Direction facing,
    Vec2? gridHeading,
    bool isBoosting = false,
    bool hasGun = false,
    bool drawGroundShadow = true,
    List<Color> passengerColors = const [],
  }) {
    // Resolve grid-space heading (col, row components)
    Vec2 gh;
    if (gridHeading != null && (gridHeading.x != 0 || gridHeading.y != 0)) {
      gh = gridHeading;
    } else {
      gh = switch (facing) {
        Direction.right || Direction.none => Vec2(1, 0),
        Direction.left => Vec2(-1, 0),
        Direction.down => Vec2(0, 1),
        Direction.up => Vec2(0, -1),
      };
    }
    final hLen = math.sqrt(gh.x * gh.x + gh.y * gh.y);
    final gfx = gh.x / math.max(hLen, 0.001);
    final gfy = gh.y / math.max(hLen, 0.001);

    // Pick the camera-facing lateral direction in grid space.
    // Isometric camera is at (-∞,-∞); a face is visible if its outward grid
    // normal (nx,ny) satisfies nx + ny < 0.
    // Two perpendicular options: A=(-gfy,gfx) sumA=gfx-gfy, B=(gfy,-gfx) sumB=gfy-gfx.
    // Choose whichever has the more-negative sum (more visible).
    final useA = gfx < gfy;
    final nearGsx = useA ? -gfy : gfy;
    final nearGsy = useA ? gfx : -gfx;

    // Screen-space unit vectors derived from grid (ensures grid-aligned faces).
    // All p() dimensions are in screen pixels for consistent size across directions.
    final rawFwdX = (gfx - gfy) * 32.0;
    final rawFwdY = (gfx + gfy) * 16.0;
    final fwdScrLen = math.sqrt(math.max(rawFwdX * rawFwdX + rawFwdY * rawFwdY, 0.001));
    final fwdUnit = Offset(rawFwdX / fwdScrLen, rawFwdY / fwdScrLen);

    final rawNrX = (nearGsx - nearGsy) * 32.0;
    final rawNrY = (nearGsx + nearGsy) * 16.0;
    final nrScrLen = math.sqrt(math.max(rawNrX * rawNrX + rawNrY * rawNrY, 0.001));
    final nearUnit = Offset(rawNrX / nrScrLen, rawNrY / nrScrLen);

    // p(fwdPx, latPx, hPx): all in screen pixels.
    // fwdPx along grid-aligned forward unit, latPx along grid-aligned near-side unit,
    // hPx purely vertical (isometric height lift).
    Offset p(double fwdPx, double latPx, double hPx) => Offset(
          fwdUnit.dx * fwdPx + nearUnit.dx * latPx,
          fwdUnit.dy * fwdPx + nearUnit.dy * latPx - hPx,
        );

    // Wheel as proper isometric ellipse: rim traces fwdUnit × vertical axes.
    Path wheelPath(Offset center, double r) {
      final path = Path();
      const steps = 24;
      for (var i = 0; i <= steps; i++) {
        final t = i * 2 * math.pi / steps;
        final dx = fwdUnit.dx * r * math.cos(t);
        final dy = fwdUnit.dy * r * math.cos(t) - r * math.sin(t);
        if (i == 0) {
          path.moveTo(center.dx + dx, center.dy + dy);
        } else {
          path.lineTo(center.dx + dx, center.dy + dy);
        }
      }
      return path..close();
    }

    // Front face is visible when moving toward the camera: gfx + gfy < 0
    final frontVisible = (gfx + gfy) < -0.05;

    // Dimensions in screen pixels (consistent visual size across all directions)
    const hl = 18.0; // half-length
    const hw = 6.5; // half-width
    const bH = 7.0; // body top height
    final cH = isPolice ? 16.0 : 19.0; // taxi cabin is taller/more upright

    // Body corners at ground (hPx=0) and body-top (hPx=bH)
    final fn0 = p(hl, hw, 0);
    final ff0 = p(hl, -hw, 0);
    final rf0 = p(-hl, -hw, 0);
    final rn0 = p(-hl, hw, 0);
    final fn1 = p(hl, hw, bH);
    final ff1 = p(hl, -hw, bH);
    final rf1 = p(-hl, -hw, bH);
    final rn1 = p(-hl, hw, bH);

    Path quad(Offset a, Offset b, Offset c, Offset d) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();

    // Color palette — isometric light from above-front (same direction as camera)
    final bodyBase = isPolice ? bodyColor : const Color(0xFFFFCC00);
    final topCol     = Color.lerp(bodyBase, Colors.white, 0.32)!;
    final endCol     = Color.lerp(bodyBase, Colors.white, 0.10)!;
    final sideCol    = Color.lerp(bodyBase, Colors.black, 0.32)!;
    final hiddenEnd  = Color.lerp(bodyBase, Colors.black, 0.55)!;
    final farSideCol = Color.lerp(bodyBase, Colors.black, 0.65)!;
    final groundCol  = Color.lerp(bodyBase, Colors.black, 0.80)!;
    final roofCol    = Color.lerp(bodyBase, Colors.white, 0.48)!;
    final glassCol = isPolice
        ? const Color(0xFF90CAF9).withValues(alpha: 0.90)
        : const Color(0xFF1A3A5C); // fully opaque — no see-through interior
    final ol = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.black.withValues(alpha: 0.55);

    canvas.save();
    canvas.translate(pos.dx, pos.dy - 2);

    // Ground shadow
    if (drawGroundShadow) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 5), width: 34, height: 11),
        Paint()..color = Colors.black.withValues(alpha: 0.20),
      );
    }

    // Boost flame
    if (isBoosting) {
      final pulse = 0.70 + math.sin(animTime * 32).abs() * 0.30;
      final rc = p(-hl - 3.0, 0, bH * 0.45);
      final tip = rc - fwdUnit * 18;
      final fs = nearUnit * 5.0;
      canvas.drawPath(
        Path()
          ..moveTo((rc + fs).dx, (rc + fs).dy)
          ..quadraticBezierTo(tip.dx, tip.dy, (rc - fs).dx, (rc - fs).dy)
          ..close(),
        Paint()..color = const Color(0xFFFF9800).withValues(alpha: 0.52 * pulse),
      );
      canvas.drawPath(
        Path()
          ..moveTo((rc + fs * 0.45).dx, (rc + fs * 0.45).dy)
          ..quadraticBezierTo(
            (rc - fwdUnit * 10).dx,
            (rc - fwdUnit * 10).dy,
            (rc - fs * 0.45).dx,
            (rc - fs * 0.45).dy,
          )
          ..close(),
        Paint()..color = const Color(0xFFFFF176).withValues(alpha: 0.66 * pulse),
      );
    }

    // Wheel paints shared by both sides
    const wR = 4.0;
    final wPaint = Paint()..color = const Color(0xFF1A1A2E);
    final rimPaint = Paint()..color = const Color(0xFFCFD8DC);
    final hubPaint = Paint()..color = const Color(0xFF546E7A);

    // Far-side wheels — front only (rear omitted, it reads as trunk in isometric).
    for (final fw in [hl * 0.56]) {
      final wc = p(fw, -(hw + wR * 0.65), wR);
      canvas.drawPath(wheelPath(wc, wR), wPaint);
      canvas.drawPath(wheelPath(wc, wR * 0.55), rimPaint);
      canvas.drawPath(wheelPath(wc, wR * 0.25), hubPaint);
    }

    // Draw all 6 faces back-to-front so no gaps show through.
    // Back-facing faces first (dark), then camera-facing faces on top.
    canvas.drawPath(quad(fn0, ff0, rf0, rn0), Paint()..color = groundCol);  // base
    canvas.drawPath(quad(ff0, rf0, rf1, ff1), Paint()..color = farSideCol); // far wall

    // Far-side checker stripes — end near cabin front (fwd ≈ 6.0).
    if (!isPolice) {
      const nBands = 6;
      const stripeStart = -13.0; // rear door end
      const stripeEnd   =  6.0;  // near cabin front
      final bandSpan = stripeEnd - stripeStart;
      for (var i = 0; i < nBands; i++) {
        final f0 = stripeStart + i * bandSpan / nBands;
        final f1 = stripeStart + (i + 1) * bandSpan / nBands;
        canvas.drawPath(
          quad(p(f1, -hw, 2.2), p(f0, -hw, 2.2),
               p(f0, -hw, 4.8), p(f1, -hw, 4.8)),
          Paint()..color = i.isEven
              ? Colors.black.withValues(alpha: 0.60)
              : Colors.white.withValues(alpha: 0.55),
        );
      }
    } else {
      canvas.drawPath(
        quad(p(hl - 2.0, -hw, 2.2), p(-hl + 3.0, -hw, 2.2),
             p(-hl + 3.0, -hw, 4.8), p(hl - 2.0, -hw, 4.8)),
        Paint()..color = const Color(0xFF1565C0).withValues(alpha: 0.55),
      );
    }

    if (frontVisible) {
      canvas.drawPath(quad(rf0, rn0, rn1, rf1), Paint()..color = hiddenEnd); // hidden rear
    } else {
      canvas.drawPath(quad(fn0, ff0, ff1, fn1), Paint()..color = hiddenEnd); // hidden front
    }
    canvas.drawPath(quad(rn0, fn0, fn1, rn1), Paint()..color = sideCol);    // near wall
    canvas.drawPath(quad(fn1, ff1, rf1, rn1), Paint()..color = topCol);     // top
    if (frontVisible) {
      canvas.drawPath(quad(fn0, ff0, ff1, fn1), Paint()..color = endCol);   // visible front
    } else {
      canvas.drawPath(quad(rf0, rn0, rn1, rf1), Paint()..color = endCol);   // visible rear
    }
    canvas.drawPath(quad(rn0, fn0, fn1, rn1), ol);
    canvas.drawPath(quad(fn1, ff1, rf1, rn1), ol);

    // Near-side wheels — drawn after the body so they appear in front of it.
    for (final fw in [-hl * 0.56, hl * 0.56]) {
      final wc = p(fw, hw + wR * 0.65, wR);
      canvas.drawPath(wheelPath(wc, wR), wPaint);
      canvas.drawPath(wheelPath(wc, wR * 0.55), rimPaint);
      canvas.drawPath(wheelPath(wc, wR * 0.25), hubPaint);
    }

    // Hood panel — flat for taxi sedan, slightly raised for police
    final hoodEndFwd = isPolice ? 6.0 : 9.0;
    final hoodRaise  = isPolice ? 2.0 : 0.5;
    canvas.drawPath(
      quad(p(hl, hw, bH), p(hl, -hw, bH), p(hoodEndFwd, -hw, bH + hoodRaise), p(hoodEndFwd, hw, bH + hoodRaise)),
      Paint()..color = isPolice
          ? const Color(0xFFF3F3F3)
          : Color.lerp(bodyBase, Colors.white, 0.22)!,
    );

    // Cabin (pixel coords) — boxy upright sedan for taxi, rakish for police
    final cf  = isPolice ? 7.0  : 9.0;   // cabin front fwd px
    final cr  = isPolice ? -13.0 : -14.0; // cabin rear fwd px
    final chw = isPolice ? 6.5  : 7.5;   // taxi roof barely narrows
    final pillarF = isPolice ? 3.0 : 1.5; // A-pillar rake (taxi = upright)
    final pillarR = isPolice ? 4.0 : 2.0; // C-pillar rake (taxi = upright)
    final cnf = p(cf, hw * 0.82, bH);
    final cff = p(cf, -hw * 0.82, bH);
    final crf = p(cr, -hw * 0.84, bH);
    final crn = p(cr, hw * 0.84, bH);
    final cnfT = p(cf - pillarF, chw, cH);
    final cffT = p(cf - pillarF, -chw, cH);
    final crfT = p(cr + pillarR, -chw, cH);
    final crnT = p(cr + pillarR, chw, cH);

    // Cabin: back faces first, then near side, then roof
    canvas.drawPath(quad(cff, crf, crfT, cffT),   Paint()..color = farSideCol);
    if (frontVisible) {
      canvas.drawPath(quad(crf, crn, crnT, crfT), Paint()..color = hiddenEnd);
    } else {
      canvas.drawPath(quad(cnf, cff, cffT, cnfT), Paint()..color = hiddenEnd);
    }
    // Near cabin wall — taxi uses the same glass colour as the windows so no
    // yellow body colour is visible through the frame. Police keeps body tint.
    canvas.drawPath(quad(crn, cnf, cnfT, crnT),
        Paint()..color = isPolice
            ? Color.lerp(bodyBase, Colors.black, 0.42)!
            : glassCol);
    if (frontVisible) {
      canvas.drawPath(quad(cnf, cff, cffT, cnfT), Paint()..color = glassCol);
      // Glass reflection — diagonal highlight on the near third of the windshield
      final glint = Offset.lerp;
      canvas.drawPath(
        quad(cnf, glint(cnf, cff, 0.38)!, glint(cnfT, cffT, 0.38)!, cnfT),
        Paint()..color = Colors.white.withValues(alpha: isPolice ? 0.14 : 0.20),
      );
    } else {
      canvas.drawPath(quad(crf, crn, crnT, crfT), Paint()..color = glassCol);
      final glint = Offset.lerp;
      canvas.drawPath(
        quad(crn, glint(crn, crf, 0.38)!, glint(crnT, crfT, 0.38)!, crnT),
        Paint()..color = Colors.white.withValues(alpha: isPolice ? 0.14 : 0.20),
      );
    }
    canvas.drawPath(quad(cnfT, cffT, crfT, crnT), Paint()..color = roofCol);
    canvas.drawPath(quad(crn, cnf, cnfT, crnT), ol);
    canvas.drawPath(quad(cnfT, cffT, crfT, crnT), ol);

    // Near-side window
    canvas.drawPath(
      quad(
        p(cf - pillarF, hw * 0.90, bH + 1.5),
        p(cr + pillarR, hw * 0.94, bH + 1.5),
        p(cr + pillarR + 1.0, hw * 0.76, cH - 5.0),
        p(cf - pillarF - 1.0, hw * 0.72, cH - 5.0),
      ),
      Paint()..color = glassCol.withValues(alpha: 1.0),
    );

    // ── Passengers visible through near-side window (taxi only) ───────────────
    if (!isPolice && passengerColors.isNotEmpty) {
      final count = passengerColors.length.clamp(0, 4);
      // Fwd positions: spread from front to rear of cabin interior
      const fwdSeats = [5.0, -1.0, -6.0, -11.0];
      // Clip drawing to the window polygon so silhouettes don't overflow
      final winClip = Path()
        ..moveTo(p(cf - pillarF,        hw * 0.90, bH + 1.5).dx,
                 p(cf - pillarF,        hw * 0.90, bH + 1.5).dy)
        ..lineTo(p(cr + pillarR,        hw * 0.94, bH + 1.5).dx,
                 p(cr + pillarR,        hw * 0.94, bH + 1.5).dy)
        ..lineTo(p(cr + pillarR + 1.0, hw * 0.76, cH - 5.0).dx,
                 p(cr + pillarR + 1.0, hw * 0.76, cH - 5.0).dy)
        ..lineTo(p(cf - pillarF - 1.0, hw * 0.72, cH - 5.0).dx,
                 p(cf - pillarF - 1.0, hw * 0.72, cH - 5.0).dy)
        ..close();
      canvas.save();
      canvas.clipPath(winClip);
      for (var i = 0; i < count; i++) {
        final fw = fwdSeats[i];
        // Shirt / body
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: p(fw, hw * 0.58, cH - 11.5), width: 6.0, height: 5.5),
            const Radius.circular(1.5),
          ),
          Paint()..color = passengerColors[i].withValues(alpha: 0.90),
        );
        // Head (skin tone)
        canvas.drawCircle(
          p(fw, hw * 0.56, cH - 6.5),
          3.2,
          Paint()..color = const Color(0xFFFFCC80),
        );
        // Hair (top half dark)
        canvas.drawArc(
          Rect.fromCenter(
              center: p(fw, hw * 0.56, cH - 6.5), width: 6.4, height: 6.4),
          math.pi, math.pi, false,
          Paint()..color = const Color(0xFF3E2723),
        );
      }
      canvas.restore();
    }

    // Wheel arches over each near-side wheel
    final archPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Color.lerp(bodyBase, Colors.black, 0.55)!
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (final fw in [-hl * 0.56, hl * 0.56]) {
      const aHW = 6.5;
      final aL = p(fw - aHW, hw, bH * 0.10);
      final aM = p(fw, hw, bH + 3.0);
      final aR = p(fw + aHW, hw, bH * 0.10);
      canvas.drawPath(
        Path()
          ..moveTo(aL.dx, aL.dy)
          ..quadraticBezierTo(aM.dx, aM.dy, aR.dx, aR.dy),
        archPaint,
      );
    }

    // Door separator — gives the boxy sedan silhouette (taxi only)
    if (!isPolice) {
      final doorPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p(1.5, hw + 0.3, bH * 0.1), p(1.5, hw + 0.3, cH - 1.5), doorPaint);
    }

    // Near-side checker stripes — end near cabin front (fwd ≈ 6.0).
    if (!isPolice) {
      const nBands = 6;
      const stripeStart = -13.0;
      const stripeEnd   =  6.0;
      final bandSpan = stripeEnd - stripeStart;
      for (var i = 0; i < nBands; i++) {
        final f0 = stripeStart + i * bandSpan / nBands;
        final f1 = stripeStart + (i + 1) * bandSpan / nBands;
        canvas.drawPath(
          quad(p(f1, hw, 2.2), p(f0, hw, 2.2),
               p(f0, hw, 4.8), p(f1, hw, 4.8)),
          Paint()..color = i.isEven
              ? Colors.black87
              : Colors.white.withValues(alpha: 0.90),
        );
      }
    } else {
      canvas.drawPath(
        quad(p(hl - 2.0, hw, 2.2), p(-hl + 3.0, hw, 2.2),
             p(-hl + 3.0, hw, 4.8), p(hl - 2.0, hw, 4.8)),
        Paint()..color = const Color(0xFF1565C0).withValues(alpha: 0.82),
      );
    }

    // Headlights and tail lights
    for (final lt in [-hw * 0.55, hw * 0.55]) {
      canvas.drawCircle(p(hl + 0.5, lt, 3.0), 1.8, Paint()..color = const Color(0xFFFFF59D));
      canvas.drawCircle(p(-hl - 0.5, lt, 2.8), 1.8, Paint()..color = const Color(0xFFEF5350));
    }

    // Roof center point (for sign / light bar / gun)
    final roofCtr = p(-2.0, 0, cH + 1.5);

    if (isPolice) {
      final active = isChasing && animTime % 0.28 < 0.14;
      canvas.drawLine(
        roofCtr - nearUnit * 7,
        roofCtr + nearUnit * 7,
        Paint()
          ..color = active ? Colors.red : Colors.blue
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        roofCtr + fwdUnit * 3,
        roofCtr + fwdUnit * 14,
        Paint()
          ..color = const Color(0xFF263238)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: roofCtr, width: 15, height: 5.5),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFFFF176),
      );
      final tp = _getTaxiRoofPainter();
      tp.paint(canvas, roofCtr - Offset(tp.width / 2, tp.height / 2));
    }

    if (hasGun) {
      canvas.drawLine(
        roofCtr + fwdUnit * 3,
        roofCtr + fwdUnit * 14,
        Paint()
          ..color = const Color(0xFF263238)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        roofCtr + fwdUnit * 14,
        2,
        Paint()..color = const Color(0xFF546E7A),
      );
    }

    canvas.restore();
  }

  // ?�?� Desert sand wind (highway theme only) ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�

  void _drawSandWindEffect(Canvas canvas, Size size) {
    if (_themeId != 'highway') return;
    final t = engine.animTime;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < 70; i++) {
      final speed = _sandSpeeds[i];
      final xFrac = (_sandPhases[i] + t * speed / (size.width + 120)) % 1.0;
      final x = xFrac * (size.width + 120) - 60;
      final y = _sandYFracs[i] * size.height;
      final alpha =
          _sandAlphas[i] * (0.6 + 0.4 * math.sin(t * 2.5 + _sandCycles[i]));
      paint
        ..color = const Color(
          0xFFD4A55A,
        ).withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeWidth = _sandThicks[i];
      final len = _sandLens[i];
      canvas.drawLine(Offset(x, y), Offset(x + len, y + len * 0.08), paint);
    }
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}

class _Entity {
  final double depth;
  final void Function(Canvas) draw;
  _Entity({required this.depth, required this.draw});
}
