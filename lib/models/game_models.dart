import 'dart:math';
import 'package:flutter/material.dart';

enum Direction { up, down, left, right, none }

enum TileType { road, sidewalk, building, park, water, intersection }

enum PassengerState { waiting, inTaxi, delivered }

enum PoliceState { patrolling, chasing, stunned }

class Vec2 {
  double x, y;
  Vec2(this.x, this.y);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);

  double get length => sqrt(x * x + y * y);

  Vec2 normalized() {
    final l = length;
    if (l == 0) return Vec2(0, 0);
    return Vec2(x / l, y / l);
  }

  double distanceTo(Vec2 other) => (this - other).length;

  @override
  String toString() => 'Vec2($x, $y)';
}

class MapTile {
  final TileType type;
  final int variant;
  final bool walkable;

  const MapTile({required this.type, this.variant = 0, this.walkable = false});
}

class Passenger {
  final String id;
  Vec2 gridPos;
  Vec2 destination;
  PassengerState state;
  final Color color;
  double waitTimer;
  final String hailPhrase;
  double fareDistance;
  static const double maxWaitTime = 30.0;

  static const List<String> _phrases = [
    // Urgent / desperate
    'TAXI!!!', '택시!!! 여기요!', "I'm SO late!!", '비행기 놓친다!!',
    'PLEASE STOP!!', '10분밖에 없어!!', 'Oh come ON!!', '제발요 제발!!',
    // Frustrated
    'WHERE ARE THE TAXIS?!', '아 진짜!!', '20분째야 이거!!',
    'Not again...', '어디 있어!!', 'This is insane!', '미치겠다 진짜...',
    // Calling out
    'HEY!! OVER HERE!', '여기요~ 택시요~', 'YO! TAXI!', '잠깐만요!!',
    'EXCUSE ME!', '이쪽이요!!', 'Right here!!', '저요 저요!!',
    // Pleading
    "I'll tip extra!", '제발 한 대만요!', 'I really need this...',
    '늦으면 죽어요 나...', 'My boss will fire me!', '회의가 5분 후야!!',
    // Resigned / muttering
    "Where's my Uber...", '걸어가야 하나...', 'Fine. FINE.',
    '아 오늘 왜 이래...', 'Just my luck.', '택시가 없네 그냥...',
  ];

  static String randomPhrase(Random rng) =>
      _phrases[rng.nextInt(_phrases.length)];

  Passenger({
    required this.id,
    required this.gridPos,
    required this.destination,
    this.state = PassengerState.waiting,
    required this.color,
    this.waitTimer = 0,
    required this.hailPhrase,
    this.fareDistance = 0,
  });
}

/// Police unit. All position/path values are in **grid units** (col, row).
class PoliceUnit {
  final String id;
  Vec2 pos; // grid coords (col, row) as floats
  Direction facing;
  Vec2 heading;
  PoliceState state;
  double stunTimer;

  // Patrol
  List<Vec2> patrolPath;
  int patrolIndex;

  // Config
  final double speed; // grid tiles per second
  final double detectionRadius; // grid tiles

  // A* path following
  List<Vec2> currentPath;
  int pathStep;
  double pathRecalcTimer;

  // Shooting
  double shootTimer;
  double muzzleFlashTimer;

  PoliceUnit({
    required this.id,
    required this.pos,
    this.facing = Direction.down,
    Vec2? heading,
    this.state = PoliceState.patrolling,
    this.stunTimer = 0,
    this.patrolPath = const [],
    this.patrolIndex = 0,
    required this.speed,
    required this.detectionRadius,
    this.currentPath = const [],
    this.pathStep = 0,
    this.pathRecalcTimer = 0,
    this.shootTimer = 0,
    this.muzzleFlashTimer = 0,
  }) : heading = heading ?? Vec2(1, 0);
}

class Bullet {
  final String id;
  Vec2 pos; // grid coords
  final Vec2 vel; // grid tiles per second
  double lifetime;
  final bool fromTaxi;

  Bullet({
    required this.id,
    required this.pos,
    required this.vel,
    this.lifetime = 4.5,
    this.fromTaxi = false,
  });
}

class LifePickup {
  final String id;
  Vec2 gridPos;

  LifePickup({required this.id, required this.gridPos});
}

class MapConfig {
  final String id;
  final String name;
  final String description;
  final int gridWidth;
  final int gridHeight;
  final int difficulty;
  final int policeCount;
  final double policeSpeed; // grid tiles per second
  final double policeDetectRadius; // grid tiles
  final int passengersToNextLevel;
  final int totalLevels;
  final Color primaryColor;
  final Color accentColor;
  final String unlockRequirement;

  const MapConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.gridWidth,
    required this.gridHeight,
    required this.difficulty,
    required this.policeCount,
    required this.policeSpeed,
    required this.policeDetectRadius,
    required this.passengersToNextLevel,
    required this.totalLevels,
    required this.primaryColor,
    required this.accentColor,
    required this.unlockRequirement,
  });
}

class GameState {
  int score;
  int level;
  int passengersDelivered;
  int passengersInTaxi;
  int maxPassengersInTaxi;
  int lives;
  double gameTime;
  bool isGameOver;
  bool isPaused;
  bool levelCompleted;
  bool isMapCleared;
  int cash;

  GameState({
    this.score = 0,
    this.level = 1,
    this.passengersDelivered = 0,
    this.passengersInTaxi = 0,
    this.maxPassengersInTaxi = 3,
    this.lives = 3,
    this.gameTime = 0,
    this.isGameOver = false,
    this.isPaused = false,
    this.levelCompleted = false,
    this.isMapCleared = false,
    this.cash = 0,
  });
}
