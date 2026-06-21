import 'package:flutter/material.dart';
import 'game_models.dart';

class MapData {
  static const List<MapConfig> maps = [
    MapConfig(
      id: 'downtown',
      name: 'Downtown',
      description: '도심 지역\n좁은 골목과 많은 신호등',
      gridWidth: 20,
      gridHeight: 20,
      difficulty: 1,
      policeCount: 2,
      policeSpeed: 2.0,
      policeDetectRadius: 7.0,
      passengersToNextLevel: 5,
      totalLevels: 3,
      primaryColor: Color(0xFF1A237E),
      accentColor: Color(0xFF42A5F5),
      unlockRequirement: '',
    ),
    MapConfig(
      id: 'suburbs',
      name: 'Suburbs',
      description: '교외 지역\n넓은 도로와 공원',
      gridWidth: 28,
      gridHeight: 28,
      difficulty: 2,
      policeCount: 3,
      policeSpeed: 2.6,
      policeDetectRadius: 9.0,
      passengersToNextLevel: 7,
      totalLevels: 4,
      primaryColor: Color(0xFF1B5E20),
      accentColor: Color(0xFF66BB6A),
      unlockRequirement: 'downtown',
    ),
    MapConfig(
      id: 'highway',
      name: 'Highway',
      description: '고속도로\n빠른 경찰차와 긴 직선로',
      gridWidth: 36,
      gridHeight: 36,
      difficulty: 3,
      policeCount: 4,
      policeSpeed: 3.2,
      policeDetectRadius: 11.0,
      passengersToNextLevel: 10,
      totalLevels: 5,
      primaryColor: Color(0xFF4A148C),
      accentColor: Color(0xFFAB47BC),
      unlockRequirement: 'suburbs',
    ),
    MapConfig(
      id: 'night_city',
      name: 'Night City',
      description: '야간 도시\n시야 제한, 최강 경찰',
      gridWidth: 32,
      gridHeight: 32,
      difficulty: 4,
      policeCount: 5,
      policeSpeed: 3.8,
      policeDetectRadius: 13.0,
      passengersToNextLevel: 12,
      totalLevels: 5,
      primaryColor: Color(0xFFB71C1C),
      accentColor: Color(0xFFEF5350),
      unlockRequirement: 'highway',
    ),
  ];

  static List<List<int>> generateMapLayout(MapConfig config) {
    final w = config.gridWidth;
    final h = config.gridHeight;

    final grid = List.generate(
      h,
      (_) => List.filled(w, TileType.sidewalk.index),
    );

    // Horizontal roads (2 tiles wide)
    for (int r = 3; r < h - 2; r += 5) {
      for (int c = 0; c < w; c++) {
        grid[r][c] = TileType.road.index;
        if (r + 1 < h) grid[r + 1][c] = TileType.road.index;
      }
    }

    // Vertical roads (2 tiles wide)
    for (int c = 3; c < w - 2; c += 5) {
      for (int r = 0; r < h; r++) {
        grid[r][c] = TileType.road.index;
        if (c + 1 < w) grid[r][c + 1] = TileType.road.index;
      }
    }

    // Fill every non-road tile with a building (no bare sidewalk gaps)
    for (int r = 0; r < h; r++) {
      for (int c = 0; c < w; c++) {
        if (grid[r][c] == TileType.sidewalk.index) {
          grid[r][c] = TileType.building.index;
        }
      }
    }

    // Border roads (perimeter always clear)
    for (int c = 0; c < w; c++) {
      grid[0][c] = TileType.road.index;
      grid[1][c] = TileType.road.index;
      grid[h - 2][c] = TileType.road.index;
      grid[h - 1][c] = TileType.road.index;
    }
    for (int r = 0; r < h; r++) {
      grid[r][0] = TileType.road.index;
      grid[r][1] = TileType.road.index;
      grid[r][w - 2] = TileType.road.index;
      grid[r][w - 1] = TileType.road.index;
    }

    return grid;
  }
}

class Random {
  final int seed;
  int _state;

  Random(this.seed) : _state = seed;

  double nextDouble() {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_state & 0x7FFFFFFF) / 0x7FFFFFFF;
  }

  int nextInt(int max) {
    if (max <= 0) return 0;
    return (nextDouble() * max).floor().clamp(0, max - 1);
  }
}
