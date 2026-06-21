import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_models.dart';
import '../models/map_data.dart';
import '../utils/iso_utils.dart';
import '../utils/pathfinder.dart';

class GameEngine extends ChangeNotifier {
  final MapConfig config;
  late List<List<int>> mapLayout;
  late final Pathfinder _pathfinder;

  // ── Taxi (position in GRID units: col, row as floats) ──────────────────────
  Vec2 taxiPos = Vec2(0, 0);
  Direction taxiDirection = Direction.none;
  Vec2 taxiHeading = Vec2(-1, 0);
  // Smoothly interpolated heading used only for rendering (not for collision).
  Vec2 taxiVisualHeading = Vec2(-1, 0);

  // Speed in grid tiles per second
  static const double _taxiBaseSpeed = 5.5;
  static const double _boostMultiplier = 1.75;
  static const double _boostDrainPerSecond = 0.42;
  static const double _boostRechargePerSecond = 0.20;
  static const double _minBoostToActivate = 0.06;
  static const double _jumpInitialVelocity = 180.0; // screen-px/s upward
  static const double _jumpGravity = 380.0;          // screen-px/s² downward
  double taxiSpeed = _taxiBaseSpeed;
  double boostCharge = 1.0;
  bool isBoosting = false;
  double taxiJumpHeight = 0.0; // screen-px lift for rendering
  double _jumpVelocity = 0.0;  // screen-px/s (positive = upward)
  int wheelLevel = 0;
  int seatUpgrades = 0;
  int invisibilityItems = 0;
  int gunAmmo = 0;
  int shotgunAmmo = 0;
  bool isInvisible = false;
  double _invisibilityTimer = 0;
  bool isShopOpen = false;

  // ── Entities ────────────────────────────────────────────────────────────────
  List<Passenger> passengers = [];
  List<PoliceUnit> policeUnits = [];
  List<Bullet> bullets = [];
  List<LifePickup> lifePickups = [];

  // ── State ───────────────────────────────────────────────────────────────────
  GameState gameState = GameState();
  double animTime = 0;

  // ── Camera ──────────────────────────────────────────────────────────────────
  Offset cameraOffset = Offset.zero;
  Size viewSize = Size.zero;
  bool _cameraInitialized = false;
  double dangerLevel = 0.0;

  // ── Input (keyboard held) ───────────────────────────────────────────────────
  final Set<LogicalKeyboardKey> _heldKeys = {};
  bool _wHeld = false, _sHeld = false, _aHeld = false, _dHeld = false;
  bool _shiftHeld = false;

  // ── Game-end state (stop notifying after first paint of overlay) ────────────
  bool _gameEndNotified = false;

  // ── Timers ───────────────────────────────────────────────────────────────────
  double _passengerSpawnTimer = 0;
  double _lifePickupTimer = 0;
  double _nextLifePickupInterval = 60.0;
  double _catchCooldown = 0;
  double _levelTransitionTimer = 0;
  double _catchFlashTimer = 0;
  bool get isCaughtFlashing => _catchFlashTimer > 0;

  final math.Random _rng = math.Random();
  List<Vec2> _roadCells = [];

  // ── Police path recalc interval (sec) ───────────────────────────────────────
  static const double _chaseRecalcInterval = 0.20;
  static const double _patrolRecalcInterval = 1.5;

  // ── Bullet constants ─────────────────────────────────────────────────────────
  static const double _bulletSpeed = 5.2; // grid tiles/sec
  static const double _fireInterval = 2.6; // seconds between shots per police
  static const double _bulletHitRadius = 0.55; // grid tiles

  GameEngine(this.config) {
    mapLayout = MapData.generateMapLayout(config);
    _pathfinder = Pathfinder(mapLayout, config.gridWidth, config.gridHeight);
    _collectRoadCells();
    _initTaxi();
    _spawnInitialPassengers();
    _spawnPolice();
  }

  // ── Initialisation ──────────────────────────────────────────────────────────

  void _collectRoadCells() {
    _roadCells = [];
    for (int r = 0; r < config.gridHeight; r++) {
      for (int c = 0; c < config.gridWidth; c++) {
        if (mapLayout[r][c] == TileType.road.index) {
          _roadCells.add(Vec2(c.toDouble(), r.toDouble()));
        }
      }
    }
  }

  void _initTaxi() {
    if (_roadCells.isEmpty) return;

    final cx = config.gridWidth / 2.0;
    final cy = config.gridHeight / 2.0;

    Vec2 best = _roadCells.first;
    double bestDist = double.infinity;
    for (final cell in _roadCells) {
      final d = (cell.x - cx) * (cell.x - cx) + (cell.y - cy) * (cell.y - cy);
      if (d < bestDist) {
        bestDist = d;
        best = cell;
      }
    }
    taxiPos = Vec2(best.x, best.y);
  }

  void _spawnInitialPassengers() {
    for (int i = 0; i < 3 + gameState.level; i++) {
      _spawnPassenger();
    }
  }

  Vec2 _spawnPassengerCell() {
    final taken = passengers
        .where((p) => p.state == PassengerState.waiting)
        .map((p) => p.gridPos)
        .toList();
    for (int attempt = 0; attempt < 80; attempt++) {
      final c = _roadCells[_rng.nextInt(_roadCells.length)];
      if (_dist(c.x, c.y, taxiPos.x, taxiPos.y) < 4.0) continue;
      bool tooClose = false;
      for (final p in taken) {
        if (_dist(c.x, c.y, p.x, p.y) < 4.0) {
          tooClose = true;
          break;
        }
      }
      if (!tooClose) return c;
    }
    return _randomRoadFarFrom(taxiPos.x, taxiPos.y, minDist: 3);
  }

  void _spawnPassenger() {
    if (_roadCells.isEmpty) return;

    Vec2 spawnCell = _spawnPassengerCell();
    Vec2 destCell = _randomRoadFarFrom(spawnCell.x, spawnCell.y, minDist: 5);

    const colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
    ];

    passengers.add(
      Passenger(
        id: 'p_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(9999)}',
        gridPos: Vec2(spawnCell.x, spawnCell.y),
        destination: Vec2(destCell.x, destCell.y),
        color: colors[_rng.nextInt(colors.length)],
        hailPhrase: Passenger.randomPhrase(_rng),
      ),
    );
  }

  void _spawnPolice() {
    for (int i = 0; i < config.policeCount; i++) {
      final spawnCell = _randomRoadFarFrom(taxiPos.x, taxiPos.y, minDist: 9);
      final patrol = _generatePatrolWaypoints(spawnCell, 6);
      final id = 'police_$i';

      final detectionR = config.policeDetectRadius + i * 0.5;
      // Stagger shoot timers so police don't all fire simultaneously
      final stagger = i * (_fireInterval / math.max(config.policeCount, 1));

      policeUnits.add(
        PoliceUnit(
          id: id,
          pos: Vec2(spawnCell.x, spawnCell.y),
          speed: config.policeSpeed,
          detectionRadius: detectionR,
          patrolPath: patrol,
          shootTimer: stagger,
        ),
      );
    }
  }

  Vec2 _randomRoadFarFrom(double cx, double cy, {double minDist = 0}) {
    for (int attempt = 0; attempt < 60; attempt++) {
      final c = _roadCells[_rng.nextInt(_roadCells.length)];
      final d = _dist(c.x, c.y, cx, cy);
      if (d >= minDist) return c;
    }
    return _roadCells[_rng.nextInt(_roadCells.length)];
  }

  List<Vec2> _generatePatrolWaypoints(Vec2 start, int count) {
    final pts = <Vec2>[start];
    var cur = start;
    for (int i = 0; i < count; i++) {
      final next = _randomRoadFarFrom(cur.x, cur.y, minDist: 3);
      pts.add(next);
      cur = next;
    }
    return pts;
  }

  // ── Input ───────────────────────────────────────────────────────────────────

  void onKeyDown(LogicalKeyboardKey key) {
    _heldKeys.add(key);
    _syncKeys();
    if (key == LogicalKeyboardKey.space) {
      fireTaxiGun();
    } else if (key == LogicalKeyboardKey.keyG) {
      fireShotgun();
    } else if (key == LogicalKeyboardKey.keyI) {
      useInvisibility();
    } else if (key == LogicalKeyboardKey.keyJ) {
      _startJump();
    }
  }

  void onKeyUp(LogicalKeyboardKey key) {
    _heldKeys.remove(key);
    _syncKeys();
  }

  void _syncKeys() {
    _wHeld =
        _heldKeys.contains(LogicalKeyboardKey.arrowUp) ||
        _heldKeys.contains(LogicalKeyboardKey.keyW);
    _sHeld =
        _heldKeys.contains(LogicalKeyboardKey.arrowDown) ||
        _heldKeys.contains(LogicalKeyboardKey.keyS);
    _aHeld =
        _heldKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _heldKeys.contains(LogicalKeyboardKey.keyA);
    _dHeld =
        _heldKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _heldKeys.contains(LogicalKeyboardKey.keyD);
    _shiftHeld =
        _heldKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        _heldKeys.contains(LogicalKeyboardKey.shiftRight);
  }

  void setMobileInput(Direction dir) {
    _wHeld = dir == Direction.up;
    _sHeld = dir == Direction.down;
    _aHeld = dir == Direction.left;
    _dHeld = dir == Direction.right;
  }

  void stopMobileInput() {
    _wHeld = _sHeld = _aHeld = _dHeld = false;
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  void update(double dt) {
    if (gameState.isGameOver || gameState.isMapCleared) {
      // Notify once so the overlay appears, then stop — overlays animate
      // themselves and don't need the engine ticking every frame.
      if (!_gameEndNotified) {
        _gameEndNotified = true;
        notifyListeners();
      }
      return;
    }
    _gameEndNotified = false;
    if (gameState.isPaused || isShopOpen) {
      return;
    }

    animTime += dt;
    gameState.gameTime += dt;

    if (_catchCooldown > 0) {
      _catchCooldown -= dt;
    }
    if (_catchFlashTimer > 0) {
      _catchFlashTimer -= dt;
    }
    if (_levelTransitionTimer > 0) {
      _levelTransitionTimer -= dt;
      if (_levelTransitionTimer <= 0) {
        gameState.levelCompleted = false;
      }
    }
    if (_invisibilityTimer > 0) {
      _invisibilityTimer -= dt;
      if (_invisibilityTimer <= 0) {
        isInvisible = false;
        _invisibilityTimer = 0;
      }
    }

    _updateTaxi(dt);
    _updateCamera(dt);
    _updatePolice(dt);
    _updateBullets(dt);
    _updateDangerLevel(dt);
    _checkPassengerPickup();
    _checkPassengerDelivery();
    _checkPoliceCatch();
    _checkBulletHit();
    _checkTaxiBulletHit();
    if (gameState.isGameOver) {
      notifyListeners(); // show overlay immediately this frame
      return;
    }
    _updatePassengerSpawn(dt);
    _updateLifePickupSpawn(dt);
    _checkLifePickup();

    notifyListeners();
  }

  // ── Taxi movement ────────────────────────────────────────────────────────────
  //
  // Isometric grid axes (screen directions):
  //   W → col -= 1  (screen: top-left  ↖)
  //   S → col += 1  (screen: bottom-right ↘)
  //   A → row += 1  (screen: bottom-left  ↙)
  //   D → row -= 1  (screen: top-right    ↗)
  //
  // Combined (W+D) → col-1, row-1 → screen UP  ↑
  // Combined (S+A) → col+1, row+1 → screen DOWN ↓
  // etc.

  void _updateTaxi(double dt) {
    _updateJump(dt);

    double dCol = 0, dRow = 0;

    if (_wHeld) dCol -= 1;
    if (_sHeld) dCol += 1;
    if (_aHeld) dRow += 1;
    if (_dHeld) dRow -= 1;

    final isMoving = dCol != 0 || dRow != 0;
    _updateBoost(dt, isMoving);

    if (!isMoving) return;

    // Normalize for diagonal movement
    final len = math.sqrt(dCol * dCol + dRow * dRow);
    dCol /= len;
    dRow /= len;
    taxiHeading.x = dCol;
    taxiHeading.y = dRow;

    // Facing direction
    if (dRow.abs() > dCol.abs()) {
      taxiDirection = dRow > 0 ? Direction.left : Direction.right;
    } else {
      taxiDirection = dCol > 0 ? Direction.down : Direction.up;
    }

    final currentSpeed =
        (taxiSpeed + wheelLevel * 0.35) * (isBoosting ? _boostMultiplier : 1.0);
    final spd = currentSpeed * dt;
    final newCol = taxiPos.x + dCol * spd;
    final newRow = taxiPos.y + dRow * spd;

    // Lane-centre snap strength: gently pulls the perpendicular axis toward the
    // nearest tile centre when only one axis can move (wall-sliding).
    // Uses the same exp(-k*dt) formula as the camera for frame-rate independence.
    const laneSnap = 8.0;
    final snapK = 1 - math.exp(-laneSnap * dt);

    // When airborne, bypass collision so the car can fly over buildings.
    if (taxiJumpHeight > 0) {
      taxiPos.x = newCol;
      taxiPos.y = newRow;
    } else if (_isRoad(newCol, newRow)) {
      taxiPos.x = newCol;
      taxiPos.y = newRow;
    } else if (dCol != 0 && _isRoad(newCol, taxiPos.y)) {
      // Slide along X; snap Y toward lane centre.
      taxiPos.x = newCol;
      taxiPos.y += (taxiPos.y.roundToDouble() - taxiPos.y) * snapK;
    } else if (dRow != 0 && _isRoad(taxiPos.x, newRow)) {
      // Slide along Y; snap X toward lane centre.
      taxiPos.y = newRow;
      taxiPos.x += (taxiPos.x.roundToDouble() - taxiPos.x) * snapK;
    }
    // Fully blocked: no movement, no snap — prevents oscillation against walls.

    taxiPos.x = taxiPos.x.clamp(0, config.gridWidth - 1.0);
    taxiPos.y = taxiPos.y.clamp(0, config.gridHeight - 1.0);

    // ── Smooth visual heading for rendering ──────────────────────────────────
    // The collision heading snaps instantly; the visual heading interpolates so
    // the car sprite appears to rotate smoothly instead of snapping 45°/90°.
    const visualHeadingSpeed = 14.0;
    final vk = 1 - math.exp(-visualHeadingSpeed * dt);
    taxiVisualHeading.x += (taxiHeading.x - taxiVisualHeading.x) * vk;
    taxiVisualHeading.y += (taxiHeading.y - taxiVisualHeading.y) * vk;
    // Keep normalised so the car geometry doesn't scale with the lerp magnitude.
    final vLen = math.sqrt(
      taxiVisualHeading.x * taxiVisualHeading.x +
      taxiVisualHeading.y * taxiVisualHeading.y,
    );
    if (vLen > 0.001) {
      taxiVisualHeading.x /= vLen;
      taxiVisualHeading.y /= vLen;
    }
  }

  void _updateBoost(double dt, bool isMoving) {
    final wantsBoost =
        _shiftHeld && isMoving && boostCharge > _minBoostToActivate;
    isBoosting = wantsBoost;

    if (isBoosting) {
      boostCharge = (boostCharge - _boostDrainPerSecond * dt).clamp(0.0, 1.0);
      if (boostCharge <= 0) {
        isBoosting = false;
      }
    } else {
      boostCharge = (boostCharge + _boostRechargePerSecond * dt).clamp(
        0.0,
        1.0,
      );
    }
  }

  void _startJump() {
    if (taxiJumpHeight != 0.0) return; // already airborne
    if (_isBuildingNearby()) _jumpVelocity = _jumpInitialVelocity;
  }

  bool _isBuildingNearby() {
    // The road is bordered by sidewalk first, then buildings.
    // Check 1 and 1.5 tiles ahead — if either is non-road (sidewalk, building,
    // park, water) the car is right at the edge of a block and can jump.
    for (final dist in [1.0, 1.5]) {
      final checkCol = taxiPos.x + taxiHeading.x * dist;
      final checkRow = taxiPos.y + taxiHeading.y * dist;
      if (!_isRoad(checkCol, checkRow)) return true;
    }
    return false;
  }

  void _updateJump(double dt) {
    if (_jumpVelocity == 0.0 && taxiJumpHeight == 0.0) return;
    _jumpVelocity -= _jumpGravity * dt;
    taxiJumpHeight += _jumpVelocity * dt;
    if (taxiJumpHeight <= 0.0) {
      taxiJumpHeight = 0.0;
      _jumpVelocity = 0.0;
      if (!_isRoad(taxiPos.x, taxiPos.y)) {
        _snapToNearestRoad();
      }
    }
  }

  void _snapToNearestRoad() {
    Vec2? nearest;
    double bestDist = double.infinity;
    for (final cell in _roadCells) {
      final d = _dist(cell.x, cell.y, taxiPos.x, taxiPos.y);
      if (d < bestDist) {
        bestDist = d;
        nearest = cell;
      }
    }
    if (nearest != null) {
      taxiPos = Vec2(nearest.x, nearest.y);
    }
  }

  bool _isRoad(double col, double row) {
    final c = col.round().clamp(0, config.gridWidth - 1);
    final r = row.round().clamp(0, config.gridHeight - 1);
    final t = TileType.values[mapLayout[r][c]];
    return t == TileType.road || t == TileType.intersection;
  }

  bool _isPoliceDriveable(double col, double row) {
    final c = col.round().clamp(0, config.gridWidth - 1);
    final r = row.round().clamp(0, config.gridHeight - 1);
    final t = TileType.values[mapLayout[r][c]];
    return t == TileType.road ||
        t == TileType.intersection ||
        t == TileType.sidewalk;
  }

  // ── Camera ───────────────────────────────────────────────────────────────────

  void setViewSize(Size size) {
    viewSize = size;
    if (!_cameraInitialized) {
      _snapCamera();
      _cameraInitialized = true;
    }
  }

  void _snapCamera() {
    if (viewSize == Size.zero) return;
    final sp = isoOffset(taxiPos.x, taxiPos.y);
    cameraOffset = Offset(
      viewSize.width / 2 - sp.dx,
      viewSize.height / 2 - sp.dy,
    );
  }

  void _updateCamera(double dt) {
    if (viewSize == Size.zero) return;
    final sp = isoOffset(taxiPos.x, taxiPos.y);
    final tx = viewSize.width / 2 - sp.dx;
    final ty = viewSize.height / 2 - sp.dy;
    // Frame-rate-independent smooth follow: k = 1 - e^(-speed * dt)
    final k = 1 - math.exp(-12.0 * dt);
    cameraOffset = Offset(
      cameraOffset.dx + (tx - cameraOffset.dx) * k,
      cameraOffset.dy + (ty - cameraOffset.dy) * k,
    );
  }

  // ── Police AI ─────────────────────────────────────────────────────────────────

  void _updatePolice(double dt) {
    for (final police in policeUnits) {
      if (police.state == PoliceState.stunned) {
        police.stunTimer -= dt;
        if (police.stunTimer <= 0) police.state = PoliceState.patrolling;
        continue;
      }
      if (isInvisible && police.state == PoliceState.chasing) {
        police.state = PoliceState.patrolling;
        police.currentPath = [];
        police.pathStep = 0;
      }

      // ── Detection ────────────────────────────────────────────────────────────
      final dToTaxiSq = _distSq(
        police.pos.x,
        police.pos.y,
        taxiPos.x,
        taxiPos.y,
      );
      final effectiveRadius = police.detectionRadius + gameState.level * 0.8;

      if (dToTaxiSq <= effectiveRadius * effectiveRadius) {
        if (!isInvisible && police.state != PoliceState.chasing) {
          police.state = PoliceState.chasing;
          police.pathRecalcTimer = _chaseRecalcInterval; // immediate recalc
          police.currentPath = [];
          police.pathStep = 0;
        }
      } else if (dToTaxiSq >
          (effectiveRadius + 2.0) * (effectiveRadius + 2.0)) {
        if (police.state == PoliceState.chasing) {
          // Search: head toward last known taxi position before resuming patrol
          police.state = PoliceState.patrolling;
          police.patrolPath = [
            Vec2(taxiPos.x, taxiPos.y), // last known spot
            _randomRoadCell(),
            _randomRoadCell(),
          ];
          police.patrolIndex = 0;
          police.currentPath = [];
          police.pathStep = 0;
          police.pathRecalcTimer = _patrolRecalcInterval;
        }
      }

      // ── Path recalculation ────────────────────────────────────────────────────
      police.pathRecalcTimer += dt;

      if (police.state == PoliceState.chasing) {
        if (police.pathRecalcTimer >= _chaseRecalcInterval ||
            police.pathStep >= police.currentPath.length) {
          police.pathRecalcTimer = 0;
          police.currentPath = _pathfinder.findPath(
            police.pos.x.round(),
            police.pos.y.round(),
            taxiPos.x.round(),
            taxiPos.y.round(),
          );
          police.pathStep = 0;
        }
      } else {
        // Patrol: pick a completely random road tile each interval so police
        // spread unpredictably across the map.
        if (police.pathStep >= police.currentPath.length ||
            police.pathRecalcTimer >= _patrolRecalcInterval) {
          police.pathRecalcTimer = 0;

          // Refresh patrol waypoints with fully random map-wide targets
          if (police.patrolPath.isEmpty ||
              police.patrolIndex >= police.patrolPath.length) {
            police.patrolPath = List.generate(3, (_) => _randomRoadCell());
            police.patrolIndex = 0;
          }

          final goal =
              police.patrolPath[police.patrolIndex % police.patrolPath.length];

          police.currentPath = _pathfinder.findPath(
            police.pos.x.round(),
            police.pos.y.round(),
            goal.x.toInt(),
            goal.y.toInt(),
          );
          police.pathStep = 0;

          if (police.currentPath.isEmpty) {
            police.patrolIndex++; // skip unreachable waypoint
          }
        }
      }

      // ── Shooting ─────────────────────────────────────────────────────────────
      if (police.muzzleFlashTimer > 0) police.muzzleFlashTimer -= dt;

      if (!isInvisible &&
          police.state == PoliceState.chasing &&
          _catchCooldown <= 0) {
        police.shootTimer += dt;
        if (police.shootTimer >= _fireInterval) {
          police.shootTimer -= _fireInterval;
          _fireBullet(police);
        }
      }

      // ── Follow path ───────────────────────────────────────────────────────────
      if (police.pathStep < police.currentPath.length) {
        final waypoint = police.currentPath[police.pathStep];
        final dCol = waypoint.x - police.pos.x;
        final dRow = waypoint.y - police.pos.y;
        final distToWp = math.sqrt(dCol * dCol + dRow * dRow);

        if (distToWp < 0.18) {
          police.pathStep++;
          if (police.state == PoliceState.patrolling &&
              police.pathStep >= police.currentPath.length) {
            police.patrolIndex++;
          }
        } else {
          const chaseBoost = 1.09; // fixed at level-1 value — no speed scaling
          final spd = police.state == PoliceState.chasing
              ? police.speed * chaseBoost
              : police.speed * 0.72; // faster patrol = livelier feel

          final nCol = dCol / distToWp;
          final nRow = dRow / distToWp;
          final nextCol = police.pos.x + nCol * spd * dt;
          final nextRow = police.pos.y + nRow * spd * dt;

          if (_isPoliceDriveable(nextCol, nextRow)) {
            police.pos.x = nextCol;
            police.pos.y = nextRow;
          } else if (_isPoliceDriveable(nextCol, police.pos.y)) {
            police.pos.x = nextCol;
            police.currentPath = [];
          } else if (_isPoliceDriveable(police.pos.x, nextRow)) {
            police.pos.y = nextRow;
            police.currentPath = [];
          } else {
            police.currentPath = [];
            police.pathStep = 0;
            police.pathRecalcTimer = _chaseRecalcInterval;
          }

          police.pos.x = police.pos.x.clamp(0, config.gridWidth - 1.0);
          police.pos.y = police.pos.y.clamp(0, config.gridHeight - 1.0);

          if (nRow.abs() > nCol.abs()) {
            police.facing = nRow > 0 ? Direction.left : Direction.right;
          } else {
            police.facing = nCol > 0 ? Direction.down : Direction.up;
          }
          police.heading.x = nCol;
          police.heading.y = nRow;
        }
      }
    }
  }

  // Returns a truly random road cell anywhere on the map.
  Vec2 _randomRoadCell() => _roadCells[_rng.nextInt(_roadCells.length)];

  // ── Bullets ───────────────────────────────────────────────────────────────────

  void _fireBullet(PoliceUnit police) {
    final dx = taxiPos.x - police.pos.x;
    final dy = taxiPos.y - police.pos.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.5) return; // too close, skip

    police.muzzleFlashTimer = 0.18;
    bullets.add(
      Bullet(
        id: 'b_${_rng.nextInt(999999)}',
        pos: Vec2(police.pos.x + dx / len * 0.8, police.pos.y + dy / len * 0.8),
        vel: Vec2(dx / len * _bulletSpeed, dy / len * _bulletSpeed),
      ),
    );
  }

  void _updateBullets(double dt) {
    for (final b in bullets) {
      b.pos.x += b.vel.x * dt;
      b.pos.y += b.vel.y * dt;
      b.lifetime -= dt;
    }
    bullets.removeWhere(
      (b) =>
          b.lifetime <= 0 ||
          b.pos.x < -1 ||
          b.pos.x > config.gridWidth + 1 ||
          b.pos.y < -1 ||
          b.pos.y > config.gridHeight + 1,
    );
  }

  void _checkBulletHit() {
    bool caught = false;
    bullets.removeWhere((b) {
      if (b.fromTaxi) return false; // handled separately
      if (_distSq(b.pos.x, b.pos.y, taxiPos.x, taxiPos.y) <
          _bulletHitRadius * _bulletHitRadius) {
        if (_catchCooldown <= 0) caught = true;
        return true;
      }
      return false;
    });
    // Invoke after removeWhere to avoid mutating bullets inside the iteration
    if (caught) _onCaught();
  }

  void _checkTaxiBulletHit() {
    bullets.removeWhere((b) {
      if (!b.fromTaxi) return false;
      for (final police in policeUnits) {
        if (_distSq(b.pos.x, b.pos.y, police.pos.x, police.pos.y) <
            _bulletHitRadius * _bulletHitRadius) {
          // Push the police away from the taxi
          final dx = police.pos.x - taxiPos.x;
          final dy = police.pos.y - taxiPos.y;
          final len = math
              .sqrt(dx * dx + dy * dy)
              .clamp(0.001, double.infinity);
          police.pos.x = (police.pos.x + dx / len * 2.5).clamp(
            0.0,
            config.gridWidth - 1.0,
          );
          police.pos.y = (police.pos.y + dy / len * 2.5).clamp(
            0.0,
            config.gridHeight - 1.0,
          );
          police.state = PoliceState.stunned;
          police.stunTimer = 2.0;
          police.currentPath = [];
          police.pathStep = 0;
          return true;
        }
      }
      return false;
    });
  }

  void _updateDangerLevel(double dt) {
    var targetDanger = 0.0;
    for (final police in policeUnits) {
      final radius = police.detectionRadius + gameState.level * 0.8;
      final distSq = _distSq(police.pos.x, police.pos.y, taxiPos.x, taxiPos.y);
      final dist = math.sqrt(distSq);
      final proximity = (1.0 - (dist / (radius + 3.0))).clamp(0.0, 1.0);
      final chaseBonus = police.state == PoliceState.chasing ? 0.28 : 0.0;
      targetDanger = math.max(
        targetDanger,
        (proximity + chaseBonus).clamp(0.0, 1.0),
      );
    }
    final k = targetDanger > dangerLevel ? 5.0 : 2.2;
    dangerLevel += (targetDanger - dangerLevel) * (1 - math.exp(-k * dt));
  }

  // ── Passengers ───────────────────────────────────────────────────────────────

  void _checkPassengerPickup() {
    if (gameState.passengersInTaxi >= gameState.maxPassengersInTaxi) return;

    for (final p in passengers) {
      if (p.state != PassengerState.waiting) continue;
      if (_distSq(p.gridPos.x, p.gridPos.y, taxiPos.x, taxiPos.y) < 2.25) {
        p.state = PassengerState.inTaxi;
        p.fareDistance = _dist(
          p.gridPos.x,
          p.gridPos.y,
          p.destination.x,
          p.destination.y,
        );
        gameState.passengersInTaxi = (gameState.passengersInTaxi + 1).clamp(
          0,
          gameState.maxPassengersInTaxi,
        );
        gameState.score += 10;
        break;
      }
    }
  }

  void _checkPassengerDelivery() {
    // Iterate a snapshot — _checkLevelUp and _spawnPassenger both modify
    // the passengers list, which would throw ConcurrentModificationError.
    for (final p in passengers.toList()) {
      if (p.state != PassengerState.inTaxi) continue;
      if (_distSq(p.destination.x, p.destination.y, taxiPos.x, taxiPos.y) <
          2.25) {
        p.state = PassengerState.delivered;
        gameState.passengersInTaxi = (gameState.passengersInTaxi - 1).clamp(
          0,
          gameState.maxPassengersInTaxi,
        );
        gameState.passengersDelivered++;
        final fare = (p.fareDistance * 16 + gameState.level * 18).round();
        gameState.cash += fare;
        gameState.score += 100 + gameState.level * 25 + fare;
        _checkLevelUp();
        if (!gameState.isMapCleared) _spawnPassenger();
      }
    }

    // Prune old delivered passengers
    if (passengers.length > 30) {
      passengers.removeWhere((p) => p.state == PassengerState.delivered);
    }
  }

  void _checkLevelUp() {
    final needed = config.passengersToNextLevel * gameState.level;
    if (gameState.passengersDelivered < needed) return;

    if (gameState.level < config.totalLevels) {
      gameState.level++;
      isInvisible = false;
      gameState.levelCompleted = true;
      _levelTransitionTimer = 3.0;
      gameState.score += 500;
      taxiSpeed = _taxiBaseSpeed + (gameState.level - 1) * 0.3;
      for (int i = 0; i < 2; i++) {
        _spawnPassenger();
      }
    } else {
      gameState.isMapCleared = true;
    }
  }

  // ── Collision with police ─────────────────────────────────────────────────────

  void _checkPoliceCatch() {
    if (_catchCooldown > 0 || isInvisible) return;

    for (final police in policeUnits) {
      if (_distSq(police.pos.x, police.pos.y, taxiPos.x, taxiPos.y) < 0.64) {
        _onCaught();
        return;
      }
    }
  }

  void _onCaught() {
    _catchCooldown = 2.5;
    _catchFlashTimer = 1.0;
    bullets.clear();
    gameState.lives--;

    // Drop passengers on nearby road cells
    int offset = 0;
    for (final p in passengers) {
      if (p.state != PassengerState.inTaxi) continue;
      p.state = PassengerState.waiting;
      final dropCell = _nearestRoadCell(
        taxiPos.x + offset * 0.6,
        taxiPos.y + offset * 0.4,
      );
      p.gridPos = Vec2(dropCell.x, dropCell.y);
      offset++;
    }
    gameState.passengersInTaxi = 0;

    if (gameState.lives <= 0) {
      gameState.isGameOver = true;
      _catchFlashTimer = 0;
    } else {
      _respawnTaxiSafe();
    }
  }

  Vec2 _nearestRoadCell(double col, double row) {
    Vec2 best = _roadCells.isNotEmpty ? _roadCells.first : Vec2(col, row);
    double bd = double.infinity;
    for (final cell in _roadCells) {
      final d =
          (cell.x - col) * (cell.x - col) + (cell.y - row) * (cell.y - row);
      if (d < bd) {
        bd = d;
        best = cell;
      }
    }
    return best;
  }

  void _respawnTaxiSafe() {
    // Pick road cell farthest from all police
    Vec2 best = _roadCells.isNotEmpty ? _roadCells.first : taxiPos;
    double bestScore = -1;

    for (int attempt = 0; attempt < 50; attempt++) {
      final cell = _roadCells[_rng.nextInt(_roadCells.length)];
      double minDist = double.infinity;
      for (final p in policeUnits) {
        final d = _dist(cell.x, cell.y, p.pos.x, p.pos.y);
        if (d < minDist) minDist = d;
      }
      if (minDist > bestScore) {
        bestScore = minDist;
        best = cell;
      }
    }

    taxiPos = Vec2(best.x, best.y);
    _snapCamera();
  }

  // ── Passenger spawn timer ─────────────────────────────────────────────────────

  void _updatePassengerSpawn(double dt) {
    _passengerSpawnTimer += dt;
    final interval = math.max(5.0, 13.0 - gameState.level * 1.5);

    if (_passengerSpawnTimer >= interval) {
      _passengerSpawnTimer = 0;
      final waiting = passengers
          .where((p) => p.state == PassengerState.waiting)
          .length;
      if (waiting < 4 + gameState.level) _spawnPassenger();
    }
  }

  // ── Life pickups ──────────────────────────────────────────────────────────────

  void _updateLifePickupSpawn(double dt) {
    _lifePickupTimer += dt;
    if (_lifePickupTimer >= _nextLifePickupInterval && lifePickups.length < 2) {
      _lifePickupTimer = 0;
      _nextLifePickupInterval = 45.0 + _rng.nextDouble() * 45.0;
      final cell = _randomRoadFarFrom(taxiPos.x, taxiPos.y, minDist: 5);
      lifePickups.add(
        LifePickup(
          id: 'life_${_rng.nextInt(999999)}',
          gridPos: Vec2(cell.x, cell.y),
        ),
      );
    }
  }

  void _checkLifePickup() {
    lifePickups.removeWhere((pickup) {
      if (_distSq(pickup.gridPos.x, pickup.gridPos.y, taxiPos.x, taxiPos.y) <
          1.44) {
        gameState.lives = math.min(gameState.lives + 1, 9);
        return true;
      }
      return false;
    });
  }

  // ── Utilities ─────────────────────────────────────────────────────────────────

  double _dist(double x1, double y1, double x2, double y2) =>
      math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

  double _distSq(double x1, double y1, double x2, double y2) =>
      (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);

  void togglePause() {
    gameState.isPaused = !gameState.isPaused;
    notifyListeners();
  }

  void openShop() {
    isShopOpen = true;
    stopMobileInput();
    notifyListeners();
  }

  void closeShop() {
    isShopOpen = false;
    notifyListeners();
  }

  bool buyWheel() {
    final cost = wheelCost;
    if (gameState.cash < cost) return false;
    gameState.cash -= cost;
    wheelLevel++;
    notifyListeners();
    return true;
  }

  bool buyInvisibility() {
    const cost = 180;
    if (gameState.cash < cost) return false;
    gameState.cash -= cost;
    invisibilityItems++;
    notifyListeners();
    return true;
  }

  bool buyGunAmmo() {
    const cost = 140;
    if (gameState.cash < cost) return false;
    gameState.cash -= cost;
    gunAmmo += 3;
    notifyListeners();
    return true;
  }

  bool buyShotgunAmmo() {
    const cost = 220;
    if (gameState.cash < cost) return false;
    gameState.cash -= cost;
    shotgunAmmo += 2;
    notifyListeners();
    return true;
  }

  /// Fires the shotgun: stuns every police car within 3.5 grid tiles for 3 s.
  bool fireShotgun() {
    if (shotgunAmmo <= 0) return false;
    var hit = false;
    for (final police in policeUnits) {
      final d = math.sqrt(_distSq(police.pos.x, police.pos.y, taxiPos.x, taxiPos.y));
      if (d <= 3.5) {
        police.state = PoliceState.stunned;
        police.stunTimer = 3.0;
        police.currentPath = [];
        police.pathStep = 0;
        hit = true;
      }
    }
    if (!hit) return false; // don't consume ammo if no police in range
    shotgunAmmo--;
    notifyListeners();
    return true;
  }

  bool useInvisibility() {
    if (invisibilityItems <= 0 || isInvisible) return false;
    invisibilityItems--;
    isInvisible = true;
    _invisibilityTimer = 10.0;
    bullets.removeWhere((b) => !b.fromTaxi);
    for (final police in policeUnits) {
      police.state = PoliceState.patrolling;
      police.currentPath = [];
      police.pathStep = 0;
    }
    notifyListeners();
    return true;
  }

  double get invisibilitySecondsLeft => _invisibilityTimer;

  bool fireTaxiGun() {
    if (gunAmmo <= 0) return false;
    PoliceUnit? target;
    var best = double.infinity;
    for (final police in policeUnits) {
      final d = _distSq(police.pos.x, police.pos.y, taxiPos.x, taxiPos.y);
      if (d < best && d < 64) {
        best = d;
        target = police;
      }
    }
    if (target == null) return false;

    gunAmmo--;
    final dx = target.pos.x - taxiPos.x;
    final dy = target.pos.y - taxiPos.y;
    final len = math.sqrt(dx * dx + dy * dy).clamp(0.001, double.infinity);
    bullets.add(
      Bullet(
        id: 'tb_${_rng.nextInt(999999)}',
        pos: Vec2(taxiPos.x + dx / len * 0.9, taxiPos.y + dy / len * 0.9),
        vel: Vec2(dx / len * _bulletSpeed * 1.2, dy / len * _bulletSpeed * 1.2),
        lifetime: 3.5,
        fromTaxi: true,
      ),
    );
    notifyListeners();
    return true;
  }

  bool buySeats() {
    if (seatUpgrades >= 3) return false;
    final cost = seatCost;
    if (gameState.cash < cost) return false;
    gameState.cash -= cost;
    seatUpgrades++;
    gameState.maxPassengersInTaxi = 3 + seatUpgrades;
    notifyListeners();
    return true;
  }

  int get wheelCost => 120 + wheelLevel * 90;
  int get seatCost => 200 + seatUpgrades * 120;

  int get remainingToLevelUp {
    if (gameState.level >= config.totalLevels) return 0;
    final prev = config.passengersToNextLevel * (gameState.level - 1);
    final target = config.passengersToNextLevel;
    return (target - (gameState.passengersDelivered - prev)).clamp(0, target);
  }

  double get levelProgress {
    if (gameState.level >= config.totalLevels) return 1.0;
    final prev = config.passengersToNextLevel * (gameState.level - 1);
    final target = config.passengersToNextLevel;
    return ((gameState.passengersDelivered - prev) / target).clamp(0.0, 1.0);
  }
}
