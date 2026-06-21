import 'package:flutter/material.dart';
import '../models/game_models.dart';

const double kTileW = 64.0;
const double kTileH = 32.0;
const double kBuildingH = 48.0;

/// Grid (col, row) -> Screen (x, y) isometric
Offset gridToScreen(double col, double row) {
  return Offset((col - row) * kTileW / 2, (col + row) * kTileH / 2);
}

/// Screen (x, y) -> Grid (col, row)
Offset screenToGrid(double x, double y) {
  final col = (x / kTileW + y / kTileH);
  final row = (y / kTileH - x / kTileW);
  return Offset(col, row);
}

/// World pos (pixels on a flat grid * tileW) to screen
Offset worldToScreen(Vec2 worldPos) {
  return gridToScreen(worldPos.x / kTileW, worldPos.y / kTileH);
}

Offset isoOffset(double col, double row) => gridToScreen(col, row);

Color buildingTopColor(Color base) => Color.lerp(base, Colors.white, 0.3)!;
Color buildingFrontColor(Color base) => Color.lerp(base, Colors.black, 0.15)!;
Color buildingSideColor(Color base) => Color.lerp(base, Colors.black, 0.35)!;

Color roadColor() => const Color(0xFF1F2A33);
Color roadLineColor() => const Color(0xFFFFD166);
Color sidewalkColor() => const Color(0xFF5E727D);
Color parkColor() => const Color(0xFF227A55);
Color grassColor() => const Color(0xFF44C47A);

List<Color> buildingPalette = [
  const Color(0xFF6C7A89),
  const Color(0xFF415968),
  const Color(0xFF354554),
  const Color(0xFF5C7385),
  const Color(0xFF416D9A),
  const Color(0xFF445F70),
  const Color(0xFF7B8CA7),
  const Color(0xFF4F8FA8),
];

Color getBuildingColor(int col, int row) {
  final idx = (col * 3 + row * 7) % buildingPalette.length;
  return buildingPalette[idx];
}

double getBuildingHeight(int col, int row) {
  final h = ((col * 17 + row * 31) % 3 + 1) * 24.0;
  return h;
}

Paint shadowPaint() => Paint()
  ..color = Colors.black.withValues(alpha: 0.18)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
