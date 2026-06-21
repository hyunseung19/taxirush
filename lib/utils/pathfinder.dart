import '../models/game_models.dart';

/// A* pathfinder on the isometric grid.
/// All coordinates are integer grid (col, row).
class Pathfinder {
  final List<List<int>> mapLayout;
  final int gridW, gridH;
  final Map<int, List<Vec2>> _pathCache = {};

  Pathfinder(this.mapLayout, this.gridW, this.gridH);

  static const _dirs = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
    [-1, -1], [1, 1], [-1, 1], [1, -1], // diagonals
  ];

  /// Returns grid cells (as Vec2) from police position toward goal.
  /// Returns empty list if no path found.
  List<Vec2> findPath(int sc, int sr, int gc, int gr) {
    if (sc == gc && sr == gr) return [];
    final cacheKey = (((sr * gridW + sc) * gridW * gridH) + (gr * gridW + gc));
    final cached = _pathCache[cacheKey];
    if (cached != null) return cached;

    // If goal tile is not walkable, snap to nearest walkable
    if (!_walkable(gc, gr)) {
      final alt = _nearestWalkable(gc, gr);
      if (alt == null) return [];
      gc = alt.$1;
      gr = alt.$2;
    }

    final gScore = <int, double>{};
    final fScore = <int, double>{};
    final cameFrom = <int, int>{};
    final openSet = <int>{};

    final startKey = _key(sc, sr);
    gScore[startKey] = 0;
    fScore[startKey] = _h(sc, sr, gc, gr);
    openSet.add(startKey);

    while (openSet.isNotEmpty) {
      // Pick node with lowest fScore
      int current = openSet.first;
      double bestF = fScore[current] ?? double.infinity;
      for (final k in openSet) {
        final f = fScore[k] ?? double.infinity;
        if (f < bestF) {
          bestF = f;
          current = k;
        }
      }
      openSet.remove(current);

      final cc = current % gridW;
      final cr = current ~/ gridW;

      if (cc == gc && cr == gr) {
        final path = _reconstruct(cameFrom, current);
        if (_pathCache.length > 160) {
          _pathCache.clear();
        }
        _pathCache[cacheKey] = path;
        return path;
      }

      for (final d in _dirs) {
        final nc = cc + d[0];
        final nr = cr + d[1];
        if (!_inBounds(nc, nr) || !_walkable(nc, nr)) continue;
        if (d[0] != 0 &&
            d[1] != 0 &&
            (!_walkable(cc + d[0], cr) || !_walkable(cc, cr + d[1]))) {
          continue;
        }

        // Diagonal cost 1.4, cardinal cost 1.0
        final moveCost = (d[0] != 0 && d[1] != 0) ? 1.4 : 1.0;
        final neighborKey = _key(nc, nr);
        final tentG = (gScore[current] ?? double.infinity) + moveCost;

        if (tentG < (gScore[neighborKey] ?? double.infinity)) {
          cameFrom[neighborKey] = current;
          gScore[neighborKey] = tentG;
          fScore[neighborKey] = tentG + _h(nc, nr, gc, gr);
          openSet.add(neighborKey);
        }
      }
    }

    return [];
  }

  List<Vec2> _reconstruct(Map<int, int> cameFrom, int current) {
    final path = <Vec2>[];
    var cur = current;
    while (cameFrom.containsKey(cur)) {
      path.add(Vec2((cur % gridW).toDouble(), (cur ~/ gridW).toDouble()));
      cur = cameFrom[cur]!;
    }
    return path.reversed.toList(growable: false);
  }

  int _key(int c, int r) => r * gridW + c;

  double _h(int c, int r, int gc, int gr) {
    // Octile distance (works well with 8-dir movement)
    final dx = (c - gc).abs();
    final dy = (r - gr).abs();
    return (dx + dy) + (1.4 - 2) * [dx, dy].reduce((a, b) => a < b ? a : b);
  }

  bool _inBounds(int c, int r) => c >= 0 && c < gridW && r >= 0 && r < gridH;

  bool _walkable(int c, int r) {
    if (!_inBounds(c, r)) return false;
    final t = TileType.values[mapLayout[r][c]];
    return t == TileType.road ||
        t == TileType.intersection ||
        t == TileType.sidewalk;
  }

  (int, int)? _nearestWalkable(int col, int row) {
    for (int radius = 1; radius <= 6; radius++) {
      for (int dc = -radius; dc <= radius; dc++) {
        for (int dr = -radius; dr <= radius; dr++) {
          if (dc.abs() != radius && dr.abs() != radius) continue;
          if (_inBounds(col + dc, row + dr) && _walkable(col + dc, row + dr)) {
            return (col + dc, row + dr);
          }
        }
      }
    }
    return null;
  }
}
