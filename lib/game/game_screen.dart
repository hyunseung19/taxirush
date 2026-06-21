import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/bgm_player.dart';
import '../models/game_models.dart';
import '../models/map_data.dart';
import 'game_engine.dart';
import 'game_painter.dart';
import '../widgets/hud_overlay.dart';
import '../widgets/dpad_widget.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/map_clear_overlay.dart';
import '../widgets/pause_menu.dart';
import '../widgets/shop_overlay.dart';

class GameScreen extends StatefulWidget {
  final MapConfig config;

  const GameScreen({super.key, required this.config});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameEngine _engine;
  // Reuse the painter across frames — avoids re-allocating on every rebuild.
  late GamePainter _painter;

  // Direct vsync ticker — fires exactly once per display frame with accurate
  // elapsed time, avoiding the 60-second AnimationController reset hiccup.
  late Ticker _ticker;
  Duration _prevElapsed = Duration.zero;
  bool _prevElapsedValid = false;

  // Controls popup shown once on game entry.
  bool _showControls = true;

  final FocusNode _focusNode = FocusNode();

  // Tracks whether BGM is currently meant to be playing, so _syncBgm only
  // calls play/pause on actual state changes rather than every tick.
  bool? _bgmShouldPlay;

  @override
  void initState() {
    super.initState();
    _engine  = GameEngine(widget.config);
    _painter = GamePainter(_engine);
    _ticker  = createTicker(_onTick)..start();
    _engine.addListener(_syncBgm);
    BgmPlayer.instance.play();
    _bgmShouldPlay = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  // BGM pauses during pause menu / game over / map clear / shop, resumes otherwise.
  void _syncBgm() {
    final shouldPlay = !_engine.gameState.isPaused &&
        !_engine.gameState.isGameOver &&
        !_engine.gameState.isMapCleared &&
        !_engine.isShopOpen;
    if (shouldPlay == _bgmShouldPlay) return;
    _bgmShouldPlay = shouldPlay;
    if (shouldPlay) {
      BgmPlayer.instance.play();
    } else {
      BgmPlayer.instance.pause();
    }
  }

  void _onTick(Duration elapsed) {
    // First tick: just record start time; skip the frame to avoid large dt.
    if (!_prevElapsedValid) {
      _prevElapsed = elapsed;
      _prevElapsedValid = true;
      return;
    }
    final dt = (elapsed - _prevElapsed).inMicroseconds / 1e6;
    _prevElapsed = elapsed;

    // Skip frames that are too large (tab switch) or zero.
    if (dt <= 0 || dt > 0.1) return;
    _engine.update(dt);
  }

  void _rebuild() {
    final engine = _engine;
    engine.removeListener(_syncBgm);
    setState(() {
      _engine  = GameEngine(widget.config);
      _painter = GamePainter(_engine);
      // Reset ticker baseline so dt doesn't spike on the next frame.
      _prevElapsedValid = false;
      _showControls = true;
    });
    _engine.addListener(_syncBgm);
    _bgmShouldPlay = null; // force a resync against the fresh engine state
    _syncBgm();
    engine.dispose(); // dispose old after new is assigned
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  // Saves high-score + unlocks the next map, then returns to map select.
  Future<void> _saveProgressAndReturn() async {
    final prefs = await SharedPreferences.getInstance();
    final clearedId = _engine.config.id;

    // Persist high score
    final prev = prefs.getInt('highscore_$clearedId') ?? 0;
    if (_engine.gameState.score > prev) {
      await prefs.setInt('highscore_$clearedId', _engine.gameState.score);
    }

    // Unlock the map whose unlockRequirement matches the cleared map
    final nextMap = MapData.maps.firstWhere(
      (m) => m.unlockRequirement == clearedId,
      orElse: () => _engine.config,
    );
    if (nextMap.id != clearedId) {
      final unlocked = prefs.getStringList('unlocked_maps') ?? ['downtown'];
      if (!unlocked.contains(nextMap.id)) {
        unlocked.add(nextMap.id);
        await prefs.setStringList('unlocked_maps', unlocked);
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    _engine.removeListener(_syncBgm);
    BgmPlayer.instance.stop();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          // Dismiss controls popup on any key, but still process the event.
          if (_showControls) {
            setState(() => _showControls = false);
          }
          if (event is KeyDownEvent) {
            _engine.onKeyDown(event.logicalKey);
            if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.keyP) {
              _engine.togglePause();
            }
          } else if (event is KeyUpEvent) {
            _engine.onKeyUp(event.logicalKey);
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
            _engine.setViewSize(viewSize);

            // ── Single AnimatedBuilder: one rebuild per tick instead of ~10. ──
            // All overlays, the canvas and the HUD share one listener on _engine,
            // cutting per-frame widget work from ~10 separate subtree passes to 1.
            return AnimatedBuilder(
              animation: _engine,
              builder: (context, _) => Stack(
                children: [
                  // Per-map background gradient — constant after map start.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF07111F),
                            Color.lerp(
                              const Color(0xFF07111F),
                              _engine.config.primaryColor,
                              0.18,
                            )!,
                            const Color(0xFF020409),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Game canvas — RepaintBoundary keeps it isolated from UI layer.
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _painter,
                      size: viewSize,
                    ),
                  ),

                  // Danger vignette
                  _buildDangerVignette(),

                  // HUD
                  HudOverlay(engine: _engine),

                  // Left-side item bar
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(child: ItemBar(engine: _engine)),
                  ),

                  // Mobile D-Pad
                  Positioned(
                    bottom: 32,
                    left: 32,
                    child: DPadWidget(
                      onDirectionStart: (dir) => _engine.setMobileInput(dir),
                      onDirectionEnd: () => _engine.stopMobileInput(),
                    ),
                  ),

                  // Shop button
                  Positioned(
                    bottom: 32,
                    right: 32,
                    child: GestureDetector(
                      onTap: _engine.openShop,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                    ),
                  ),

                  // Pause button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => _engine.togglePause(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.16),
                              Colors.black.withValues(alpha: 0.58),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _engine.gameState.isPaused
                                ? const Color(0xFF56F0B2).withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Icon(
                          _engine.gameState.isPaused
                              ? Icons.play_arrow
                              : Icons.tune,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),

                  // Caught flash overlay
                  if (_engine.isCaughtFlashing)
                    IgnorePointer(
                      child: Container(
                        color: Colors.red.withValues(alpha: 0.25),
                      ),
                    ),

                  // Map Clear overlay
                  if (_engine.gameState.isMapCleared)
                    MapClearOverlay(
                      score: _engine.gameState.score,
                      delivered: _engine.gameState.passengersDelivered,
                      mapName: _engine.config.name,
                      onRetry: _rebuild,
                      onMenu: _saveProgressAndReturn,
                    ),

                  // Game Over overlay
                  if (_engine.gameState.isGameOver)
                    GameOverOverlay(
                      score: _engine.gameState.score,
                      delivered: _engine.gameState.passengersDelivered,
                      onRetry: _rebuild,
                      onMenu: () => Navigator.of(context).pop(),
                    ),

                  // Shop overlay
                  if (_engine.isShopOpen)
                    ShopOverlay(
                      engine: _engine,
                      onClose: () {
                        _engine.closeShop();
                        _focusNode.requestFocus();
                      },
                    ),

                  // Pause menu
                  if (_engine.gameState.isPaused &&
                      !_engine.gameState.isGameOver &&
                      !_engine.gameState.isMapCleared)
                    PauseMenu(
                      onResume: () => _engine.togglePause(),
                      onMenu: () => Navigator.of(context).pop(),
                      onRetry: _rebuild,
                    ),

                  // Controls popup — shown once on game entry, dismiss by tap or key.
                  if (_showControls) _buildControlsPopup(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Danger vignette ───────────────────────────────────────────────────────

  Widget _buildDangerVignette() {
    final danger = _engine.dangerLevel;
    if (danger <= 0.02) return const SizedBox.shrink();
    final pulse = 0.5 + 0.5 * danger;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.redAccent.withValues(
              alpha: 0.12 + danger * 0.18 * pulse,
            ),
            width: 8 + danger * 10,
          ),
          color: const Color(0xFFB71C1C).withValues(alpha: 0.05 * danger),
        ),
      ),
    );
  }

  // ── Controls popup ────────────────────────────────────────────────────────

  Widget _buildControlsPopup() {
    return GestureDetector(
      onTap: () => setState(() => _showControls = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        alignment: Alignment.center,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFD600).withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD600).withValues(alpha: 0.12),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '조작법',
                style: TextStyle(
                  color: Color(0xFFFFD600),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 20),
              _controlHint('이동', 'WASD  /  방향키  /  D-PAD'),
              _controlHint('부스트', 'Shift + 이동'),
              _controlHint('점프', 'J'),
              _controlHint('발사', 'Space'),
              _controlHint('샷건', 'G'),
              _controlHint('일시정지', 'P  /  ESC'),
              const SizedBox(height: 22),
              Text(
                '화면을 탭하거나 아무 키를 눌러 시작',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlHint(String action, String keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              action,
              style: const TextStyle(
                color: Color(0xFF8899AA),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              keys,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
