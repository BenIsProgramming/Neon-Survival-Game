import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'input_profile.dart';
import 'leaderboard.dart';

class Player {
  final int id;
  final String name;
  final Color color;
  final InputProfile inputProfile;

  double x;
  double y;
  double health;
  double maxHealth;
  int score;
  int lives;
  bool isAlive;

  double lastShotTime = 0.0;
  Offset aimPosition = const Offset(0, 0);
  Offset lastMouseViewportPos = const Offset(400, 300);

  Player({
    required this.id,
    required this.name,
    required this.color,
    required this.inputProfile,
    required this.x,
    required this.y,
    this.health = 100.0,
    this.maxHealth = 100.0,
    this.score = 0,
    this.lives = 3,
    this.isAlive = true,
  });

  void reset(double startX, double startY, double maxHp) {
    x = startX;
    y = startY;
    maxHealth = maxHp;
    health = maxHp;
    score = 0;
    lives = 3;
    isAlive = true;
    lastShotTime = 0.0;
  }
}

class RepaintNotifier extends ChangeNotifier {
  void triggerRepaint() {
    notifyListeners();
  }
}

class NeonSurvivalEngine extends StatefulWidget {
  final List<Player> initialPlayers;
  final String difficulty;
  final VoidCallback onQuit;

  const NeonSurvivalEngine({
    Key? key,
    required this.initialPlayers,
    required this.difficulty,
    required this.onQuit,
  }) : super(key: key);

  @override
  State<NeonSurvivalEngine> createState() => _NeonSurvivalEngineState();
}

class _NeonSurvivalEngineState extends State<NeonSurvivalEngine> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final RepaintNotifier _repaintNotifier = RepaintNotifier();
  Duration _lastDuration = Duration.zero;

  // Throttled HUD update state
  int _lastCombinedScore = 0;
  int _lastHudTenth = 0;
  bool _lastHudIsGameOver = false;

  // Virtual arena size
  static const double arenaWidth = 1600.0;
  static const double arenaHeight = 1200.0;

  // Game entities
  late List<Player> _players;
  final List<_GameEnemy> _enemies = [];
  final List<_GameBullet> _bullets = [];
  final List<_VisualParticle> _particles = [];
  final Random _random = Random();

  int _enemyIdCounter = 0;
  double _elapsedTime = 0.0;
  double _lastSpawnTime = 0.0;
  bool _isGameOver = false;

  // Doors visual glow intensity
  double _topDoorGlow = 0.0;
  double _bottomDoorGlow = 0.0;
  double _leftDoorGlow = 0.0;
  double _rightDoorGlow = 0.0;

  // Camera settings
  double _cameraX = 0.0;
  double _cameraY = 0.0;
  double _zoomLevel = 1.0;

  // Keyboard keys currently pressed
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  final List<Color> _rainbowColors = [
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFF59E0B),
    const Color(0xFF10B981),
    const Color(0xFF06B6D4),
    const Color(0xFF3B82F6),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _players = widget.initialPlayers;
    _setupInitialPlayerStats();

    // Start game tick
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _setupInitialPlayerStats() {
    double maxHp = 100.0;
    if (widget.difficulty.toLowerCase() == 'easy') {
      maxHp = 150.0;
    } else if (widget.difficulty.toLowerCase() == 'hard') {
      maxHp = 75.0;
    }

    // Distribute players around the center
    final center = const Offset(arenaWidth / 2, arenaHeight / 2);
    final offsets = [
      const Offset(-40, -40),
      const Offset(40, -40),
      const Offset(-40, 40),
      const Offset(40, 40),
    ];

    for (int i = 0; i < _players.length; i++) {
      final spawnPos = center + offsets[i % offsets.length];
      _players[i].reset(spawnPos.dx, spawnPos.dy, maxHp);
    }
    _isGameOver = false;
    _enemies.clear();
    _bullets.clear();
    _particles.clear();
    _elapsedTime = 0.0;
    _lastSpawnTime = 0.0;
    _enemyIdCounter = 0;
    _cameraX = (arenaWidth / 2) - 400.0;
    _cameraY = (arenaHeight / 2) - 300.0;
    _zoomLevel = 1.0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration duration) {
    if (!mounted) return;

    double dt = 0.01667;
    if (_lastDuration != Duration.zero) {
      dt = (duration - _lastDuration).inMicroseconds / 1000000.0;
    }
    _lastDuration = duration;

    // Clamp dt to handle lag safely
    if (dt > 0.1) dt = 0.1;
    if (dt <= 0.0) dt = 0.01667;

    _updatePhysics(dt);
    _updateParticles(dt);

    // Dynamic camera centroid and zoom calculation
    _updateCamera();

    // Trigger fast repaint
    _repaintNotifier.triggerRepaint();

    // Throttle HUD rebuilds
    int combinedScore = _players.fold(0, (sum, p) => sum + p.score);
    final int currentTenth = (_elapsedTime * 10).floor();
    bool hudNeedsUpdate = false;

    if (combinedScore != _lastCombinedScore) {
      _lastCombinedScore = combinedScore;
      hudNeedsUpdate = true;
    }
    if (currentTenth != _lastHudTenth) {
      _lastHudTenth = currentTenth;
      hudNeedsUpdate = true;
    }
    if (_isGameOver != _lastHudIsGameOver) {
      _lastHudIsGameOver = _isGameOver;
      hudNeedsUpdate = true;
    }

    if (hudNeedsUpdate) {
      setState(() {});
    }
  }

  void _updatePhysics(double dt) {
    if (_isGameOver) return;

    _elapsedTime += dt;

    // Decay portals visual glow
    _topDoorGlow = max(0.0, _topDoorGlow - dt * 2.0);
    _bottomDoorGlow = max(0.0, _bottomDoorGlow - dt * 2.0);
    _leftDoorGlow = max(0.0, _leftDoorGlow - dt * 2.0);
    _rightDoorGlow = max(0.0, _rightDoorGlow - dt * 2.0);

    // 1. Move and update players
    bool anyPlayerAlive = false;
    for (final p in _players) {
      if (!p.isAlive) continue;
      anyPlayerAlive = true;

      double dx = 0.0;
      double dy = 0.0;

      // Handle keyboard move inputs
      if (_pressedKeys.contains(p.inputProfile.moveUp)) dy -= 1.0;
      if (_pressedKeys.contains(p.inputProfile.moveDown)) dy += 1.0;
      if (_pressedKeys.contains(p.inputProfile.moveLeft)) dx -= 1.0;
      if (_pressedKeys.contains(p.inputProfile.moveRight)) dx += 1.0;

      if (dx != 0.0 || dy != 0.0) {
        double mag = sqrt(dx * dx + dy * dy);
        double speed = 250.0;
        dx = (dx / mag) * speed * dt;
        dy = (dy / mag) * speed * dt;
        p.x += dx;
        p.y += dy;

        // Base arena boundary check
        p.x = p.x.clamp(20.0, arenaWidth - 20.0);
        p.y = p.y.clamp(20.0, arenaHeight - 20.0);
      }

      // Update aim direction
      if (p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
        p.aimPosition = Offset(
          p.lastMouseViewportPos.dx + _cameraX,
          p.lastMouseViewportPos.dy + _cameraY,
        );
      } else {
        // Auto aim for keys/gamepad: lock onto nearest enemy
        _GameEnemy? nearest = _findNearestEnemyTo(p.x, p.y);
        if (nearest != null) {
          p.aimPosition = Offset(nearest.x, nearest.y);
        } else {
          // Default to aiming straight up
          p.aimPosition = Offset(p.x, p.y - 100.0);
        }
      }

      // Shooting mechanics
      bool wantsToShoot = false;
      if (p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
        // Mouse aiming shoots automatically while holding Space or trigger click (handled in gesturedetector)
        if (_pressedKeys.contains(LogicalKeyboardKey.space)) {
          wantsToShoot = true;
        }
      } else {
        // Auto-shoot continuously if an enemy is in range, or if they press their shoot key
        _GameEnemy? nearest = _findNearestEnemyTo(p.x, p.y);
        if (nearest != null) {
          double dist = sqrt(pow(nearest.x - p.x, 2) + pow(nearest.y - p.y, 2));
          if (dist < 350.0) {
            wantsToShoot = true;
          }
        }
        if (_pressedKeys.contains(p.inputProfile.actionShoot)) {
          wantsToShoot = true;
        }
      }

      if (wantsToShoot && _elapsedTime - p.lastShotTime > 0.22) {
        p.lastShotTime = _elapsedTime;
        _firePlayerBullet(p);
      }
    }

    if (!anyPlayerAlive) {
      _triggerGameOver();
      return;
    }

    // 2. Clamp players to the camera bounds (Vampire Survivors shared-screen style)
    _clampPlayersToViewport();

    // 3. Enemy Spawning Logic
    double baseSpawnInterval = widget.difficulty.toLowerCase() == 'easy' ? 4.0 : (widget.difficulty.toLowerCase() == 'hard' ? 1.8 : 2.8);
    // Dynamic difficulty increase
    double spawnInterval = max(0.4, baseSpawnInterval - (_elapsedTime * 0.015));
    if (_elapsedTime - _lastSpawnTime > spawnInterval) {
      _lastSpawnTime = _elapsedTime;
      _spawnEnemy();
    }

    // 4. Update Bullets
    for (int i = _bullets.length - 1; i >= 0; i--) {
      final b = _bullets[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;

      // Clean up out of bounds bullets
      if (b.x < -50 || b.x > arenaWidth + 50 || b.y < -50 || b.y > arenaHeight + 50) {
        _bullets.removeAt(i);
      }
    }

    // 5. Update Enemies (chase nearest player)
    for (int i = _enemies.length - 1; i >= 0; i--) {
      final e = _enemies[i];

      Player? target = _findNearestAlivePlayer(e.x, e.y);
      if (target == null) continue;

      double edx = target.x - e.x;
      double edy = target.y - e.y;
      double dist = sqrt(edx * edx + edy * edy);

      if (dist > 0) {
        edx /= dist;
        edy /= dist;
      }

      if (e.type == 'shooter') {
        if (dist > 230.0) {
          e.x += edx * e.speed * dt;
          e.y += edy * e.speed * dt;
        } else if (dist < 170.0) {
          e.x -= edx * e.speed * dt;
          e.y -= edy * e.speed * dt;
        }

        // Shooter shoots
        if (_elapsedTime - e.lastShotTime > 1.8) {
          e.lastShotTime = _elapsedTime;
          _fireEnemyBullet(e.x, e.y, target.x, target.y);
        }
      } else {
        // Runners / Tanks chase directly
        e.x += edx * e.speed * dt;
        e.y += edy * e.speed * dt;
      }

      // Constrain inside boundaries once entered
      if (e.x >= 0.0 && e.x <= arenaWidth && e.y >= 0.0 && e.y <= arenaHeight) {
        e.x = e.x.clamp(12.0, arenaWidth - 12.0);
        e.y = e.y.clamp(12.0, arenaHeight - 12.0);
      }

      // Collision with player
      double colDist = e.type == 'tank' ? 24.0 : 16.0;
      if (dist < colDist) {
        double damage = e.type == 'tank' ? 25.0 : 12.0;
        target.health = max(0.0, target.health - damage * dt * 5.0);
        if (target.health <= 0) {
          _killPlayer(target);
        }
      }
    }

    // 6. Check Bullet-Player and Bullet-Enemy Collisions
    for (int bi = _bullets.length - 1; bi >= 0; bi--) {
      final b = _bullets[bi];

      if (b.isEnemy) {
        // Hits player?
        for (final p in _players) {
          if (!p.isAlive) continue;
          double dx = b.x - p.x;
          double dy = b.y - p.y;
          double dist = sqrt(dx * dx + dy * dy);
          if (dist < 16.0) {
            p.health = max(0.0, p.health - 12.0);
            _bullets.removeAt(bi);
            _spawnLocalExplosion(b.x, b.y, Colors.redAccent, count: 5);
            if (p.health <= 0) {
              _killPlayer(p);
            }
            break;
          }
        }
      } else {
        // Hits enemy?
        for (int ei = _enemies.length - 1; ei >= 0; ei--) {
          final e = _enemies[ei];
          double dx = b.x - e.x;
          double dy = b.y - e.y;
          double dist = sqrt(dx * dx + dy * dy);
          double radius = e.type == 'tank' ? 18.0 : 12.0;

          if (dist < radius) {
            e.health -= 1.0;
            _bullets.removeAt(bi);
            _spawnLocalExplosion(b.x, b.y, _rainbowColors[_random.nextInt(_rainbowColors.length)], count: 4);

            if (e.health <= 0) {
              _enemies.removeAt(ei);
              if (b.owner != null) {
                b.owner!.score += e.type == 'tank' ? 50 : (e.type == 'shooter' ? 30 : 10);
              }
              _spawnLocalExplosion(e.x, e.y, _rainbowColors[_random.nextInt(_rainbowColors.length)], count: 18);
            }
            break;
          }
        }
      }
    }
  }

  void _updateCamera() {
    final alive = _players.where((p) => p.isAlive).toList();
    if (alive.isEmpty) return;

    // Centroid calculation
    double sumX = 0;
    double sumY = 0;
    for (final p in alive) {
      sumX += p.x;
      sumY += p.y;
    }
    double targetCamX = (sumX / alive.length) - 400.0;
    double targetCamY = (sumY / alive.length) - 300.0;

    // Dynamic Zoom calculation based on spread distance
    double maxSpread = 0.0;
    for (int i = 0; i < alive.length; i++) {
      for (int j = i + 1; j < alive.length; j++) {
        double d = sqrt(pow(alive[i].x - alive[j].x, 2) + pow(alive[i].y - alive[j].y, 2));
        if (d > maxSpread) maxSpread = d;
      }
    }

    double targetZoom = 1.0;
    if (alive.length > 1) {
      double factor = (maxSpread - 100.0) / 600.0; // map 100px - 700px spread
      factor = factor.clamp(0.0, 1.0);
      targetZoom = 1.2 - (factor * 0.45); // zoom scales from 1.2x (close) down to 0.75x (apart)
    }

    // Smooth camera and zoom interpolation
    _cameraX += (targetCamX - _cameraX) * 0.12;
    _cameraY += (targetCamY - _cameraY) * 0.12;
    _zoomLevel += (targetZoom - _zoomLevel) * 0.08;

    // Clamp camera within physical boundary limits
    _cameraX = _cameraX.clamp(0.0, arenaWidth - 800.0);
    _cameraY = _cameraY.clamp(0.0, arenaHeight - 600.0);
  }

  void _clampPlayersToViewport() {
    // Determine boundaries of visible screen area at current zoom
    double halfWidth = 400.0 / _zoomLevel;
    double halfHeight = 300.0 / _zoomLevel;
    double centerX = _cameraX + 400.0;
    double centerY = _cameraY + 300.0;

    double minX = centerX - halfWidth + 18.0;
    double maxX = centerX + halfWidth - 18.0;
    double minY = centerY - halfHeight + 18.0;
    double maxY = centerY + halfHeight - 18.0;

    for (final p in _players) {
      if (!p.isAlive) continue;
      p.x = p.x.clamp(minX, maxX);
      p.y = p.y.clamp(minY, maxY);
    }
  }

  Player? _findNearestAlivePlayer(double x, double y) {
    Player? nearest;
    double minDist = double.infinity;
    for (final p in _players) {
      if (!p.isAlive) continue;
      double dist = sqrt(pow(p.x - x, 2) + pow(p.y - y, 2));
      if (dist < minDist) {
        minDist = dist;
        nearest = p;
      }
    }
    return nearest;
  }

  _GameEnemy? _findNearestEnemyTo(double x, double y) {
    _GameEnemy? nearest;
    double minDist = 360.0; // auto range locking limit
    for (final e in _enemies) {
      double dist = sqrt(pow(e.x - x, 2) + pow(e.y - y, 2));
      if (dist < minDist) {
        minDist = dist;
        nearest = e;
      }
    }
    return nearest;
  }

  void _firePlayerBullet(Player p) {
    double dx = p.aimPosition.dx - p.x;
    double dy = p.aimPosition.dy - p.y;
    double dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return;

    dx /= dist;
    dy /= dist;

    double speed = 500.0;
    _bullets.add(_GameBullet(
      x: p.x + dx * 16.0,
      y: p.y + dy * 16.0,
      vx: dx * speed,
      vy: dy * speed,
      isEnemy: false,
      owner: p,
    ));

    _spawnLocalExplosion(p.x + dx * 16.0, p.y + dy * 16.0, p.color, count: 2);
  }

  void _fireEnemyBullet(double sx, double sy, double tx, double ty) {
    double dx = tx - sx;
    double dy = ty - sy;
    double dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return;

    dx /= dist;
    dy /= dist;

    double speed = 280.0;
    _bullets.add(_GameBullet(
      x: sx + dx * 16.0,
      y: sy + dy * 16.0,
      vx: dx * speed,
      vy: dy * speed,
      isEnemy: true,
    ));
  }

  void _spawnEnemy() {
    _enemyIdCounter++;
    double x = 0.0;
    double y = 0.0;
    int portalEdge = _random.nextInt(4);

    switch (portalEdge) {
      case 0: // Top
        x = arenaWidth / 2;
        y = -10.0;
        _topDoorGlow = 1.0;
        break;
      case 1: // Right
        x = arenaWidth + 10.0;
        y = arenaHeight / 2;
        _rightDoorGlow = 1.0;
        break;
      case 2: // Bottom
        x = arenaWidth / 2;
        y = arenaHeight + 10.0;
        _bottomDoorGlow = 1.0;
        break;
      case 3: // Left
        x = -10.0;
        y = arenaHeight / 2;
        _leftDoorGlow = 1.0;
        break;
    }

    String type = 'runner';
    double hp = 1.0;
    double speed = 155.0;

    double roll = _random.nextDouble();
    if (_elapsedTime > 25.0 && roll < 0.25) {
      type = 'tank';
      hp = 4.0;
      speed = 60.0;
    } else if (_elapsedTime > 10.0 && roll < 0.50) {
      type = 'shooter';
      hp = 2.0;
      speed = 105.0;
    }

    speed += min(50.0, _elapsedTime * 0.45);

    double difficultyMultiplier = widget.difficulty.toLowerCase() == 'easy' ? 0.75 : (widget.difficulty.toLowerCase() == 'hard' ? 1.25 : 1.0);
    speed *= difficultyMultiplier;

    _enemies.add(_GameEnemy(
      id: _enemyIdCounter,
      x: x,
      y: y,
      health: hp,
      maxHealth: hp,
      type: type,
      speed: speed,
    ));
  }

  void _killPlayer(Player p) {
    p.lives--;
    _spawnLocalExplosion(p.x, p.y, p.color, count: 25);
    if (p.lives > 0) {
      // Respawn at arena center
      p.health = p.maxHealth;
      p.x = arenaWidth / 2;
      p.y = arenaHeight / 2;
    } else {
      p.isAlive = false;
    }
  }

  void _triggerGameOver() {
    if (_isGameOver) return;
    _isGameOver = true;

    // Save score entries locally
    int totalCombinedScore = _players.fold(0, (sum, p) => sum + p.score);
    String playerNames = _players.map((p) => p.name).join(' & ');
    LeaderboardManager.saveScore(playerNames, totalCombinedScore, _players.length);
  }

  void _restartGame() {
    setState(() {
      _setupInitialPlayerStats();
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_isGameOver) return;
    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);
      
      // Handle manual fire for mouse players on space press
      for (final p in _players) {
        if (p.isAlive && p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _firePlayerBullet(p);
            p.lastShotTime = _elapsedTime;
          }
        }
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
  }

  void _updateParticles(double dt) {
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.94;
      p.vy *= 0.94;
      p.life -= p.decay * dt;

      if (p.life <= 0) {
        _particles.removeAt(i);
      }
    }
  }

  void _spawnLocalExplosion(double x, double y, Color baseColor, {int count = 12}) {
    for (int i = 0; i < count; i++) {
      double angle = _random.nextDouble() * 2 * pi;
      double speed = 80.0 + _random.nextDouble() * 180.0;
      _particles.add(_VisualParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: baseColor.withOpacity(0.8 + _random.nextDouble() * 0.2),
        life: 1.0,
        decay: 1.5 + _random.nextDouble() * 1.5,
        size: 2.0 + _random.nextDouble() * 3.0,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: SafeArea(
        child: Column(
          children: [
            // Top HUD
            _buildHudBar(),
            const SizedBox(height: 12),

            // Gameplay Canvas Boundary
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double scale = min(
                    constraints.maxWidth / 800.0,
                    constraints.maxHeight / 600.0,
                  );
                  double w = 800.0 * scale;
                  double h = 600.0 * scale;

                  Widget canvasWidget = KeyboardListener(
                    focusNode: FocusNode()..requestFocus(),
                    onKeyEvent: _handleKeyEvent,
                    child: MouseRegion(
                      onHover: (e) {
                        if (_isGameOver) return;
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final localPos = box.globalToLocal(e.position);
                        double canvasLeft = (constraints.maxWidth - w) / 2;
                        double canvasTop = (constraints.maxHeight - h) / 2;

                        double viewportX = (localPos.dx - canvasLeft) / scale;
                        double viewportY = (localPos.dy - canvasTop) / scale;

                        // Give P1 mouse aim if P1 is using keyboardMouse
                        for (final p in _players) {
                          if (p.isAlive && p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
                            p.lastMouseViewportPos = Offset(viewportX, viewportY);
                          }
                        }
                        _repaintNotifier.triggerRepaint();
                      },
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_isGameOver) return;
                          for (final p in _players) {
                            if (p.isAlive && p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
                              _firePlayerBullet(p);
                              p.lastShotTime = _elapsedTime;
                            }
                          }
                        },
                        child: Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF060A13),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF1E293B),
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: const Size(800.0, 600.0),
                                painter: _NeonSurvivalPainter(
                                  state: this,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );

                  return Center(child: canvasWidget);
                },
              ),
            ),

            if (_isGameOver) _buildGameOverPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHudBar() {
    int totalScore = _players.fold(0, (sum, p) => sum + p.score);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: widget.onQuit,
          ),
          Column(
            children: [
              Text(
                'NEON SURVIVAL',
                style: TextStyle(
                  color: Colors.cyanAccent.shade200,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'DIFFICULTY: ${widget.difficulty.toUpperCase()}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SCORE: $totalScore',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'TIME: ${_elapsedTime.toStringAsFixed(1)}s',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverPanel() {
    int totalScore = _players.fold(0, (sum, p) => sum + p.score);
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.08),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ALL SHIPS DESTROYED',
                style: TextStyle(
                  color: Color(0xFFF87171),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Combined Score: $totalScore  •  Survived: ${_elapsedTime.toStringAsFixed(1)} seconds',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: widget.onQuit,
                child: const Text('MAIN MENU', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: _restartGame,
                child: const Text(
                  'PLAY AGAIN',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _NeonSurvivalPainter extends CustomPainter {
  final _NeonSurvivalEngineState state;

  // Cached paint configurations to prevent allocation overhead
  final Paint _spaceGridPaint = Paint();
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  final Paint _bulletPaint = Paint()..style = PaintingStyle.fill;
  final Paint _bulletGlowPaint = Paint();
  final Paint _enemyFillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _enemyStrokePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0;
  final Paint _enemyGlowPaint = Paint();
  final Paint _enemyHpBgPaint = Paint()..color = const Color(0xFF161B22);
  final Paint _enemyHpFillPaint = Paint();

  final Paint _playerHaloPaint = Paint()..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  final Paint _playerPaint = Paint()..style = PaintingStyle.fill;
  final Paint _playerRimPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0;
  final Paint _playerCorePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
  final Paint _playerHpBarBg = Paint()..color = const Color(0xFF1E293B)..style = PaintingStyle.fill;
  final Paint _playerHpBarFill = Paint()..style = PaintingStyle.fill;

  final Paint _laserPaint = Paint()..strokeWidth = 1.0;
  final Paint _crosshairPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5;
  final Paint _crosshairDotPaint = Paint()..color = Colors.white;

  final Paint _borderPaint = Paint()..color = const Color(0xFF1F2937)..style = PaintingStyle.stroke..strokeWidth = 5.0;
  final Paint _neonPaint = Paint()..color = const Color(0xFF06B6D4)..style = PaintingStyle.stroke..strokeWidth = 2.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  final Paint _portalBgPaint = Paint()..color = const Color(0xFF0A0F1D)..style = PaintingStyle.fill;
  final Paint _portalGlowPaint = Paint()..color = const Color(0xFFA855F7).withOpacity(0.25)..style = PaintingStyle.stroke..strokeWidth = 4.0;
  final Paint _portalLinePaint = Paint()..color = const Color(0xFFA855F7)..style = PaintingStyle.stroke..strokeWidth = 2.0;

  final Paint _bgOverlayPaint = Paint()..color = Colors.black.withOpacity(0.72);

  _NeonSurvivalPainter({
    required this.state,
  }) : super(repaint: state._repaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Initial Scale to cover the layout constraints size
    canvas.save();
    canvas.scale(size.width / 800.0, size.height / 600.0);

    // 2. Zoom & Camera Centroid Translation
    // Scale and translate relative to screen center (400, 300)
    canvas.translate(400.0, 300.0);
    canvas.scale(state._zoomLevel);
    canvas.translate(-400.0, -300.0);

    // Map content translation
    canvas.translate(-state._cameraX, -state._cameraY);

    // Subtle arena grid
    _spaceGridPaint.color = const Color(0xFF1E293B).withOpacity(0.2);
    _spaceGridPaint.strokeWidth = 1.0;

    double gridSpacing = 40.0;
    for (double x = 0; x < _NeonSurvivalEngineState.arenaWidth; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, _NeonSurvivalEngineState.arenaHeight), _spaceGridPaint);
    }
    for (double y = 0; y < _NeonSurvivalEngineState.arenaHeight; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(_NeonSurvivalEngineState.arenaWidth, y), _spaceGridPaint);
    }

    // Draw Particles
    for (final p in state._particles) {
      _particlePaint.color = p.color.withOpacity(p.life);
      canvas.drawCircle(Offset(p.x, p.y), p.size * p.life, _particlePaint);
    }

    // Draw Bullets
    for (final b in state._bullets) {
      _drawSingleBullet(canvas, b.x, b.y, b.isEnemy, b.owner?.color);
    }

    // Draw Enemies
    for (final e in state._enemies) {
      _drawSingleEnemy(canvas, e.x, e.y, e.health, e.maxHealth, e.type);
    }

    // Draw Players
    for (final p in state._players) {
      if (!p.isAlive) continue;

      // Halo
      _playerHaloPaint.color = p.color.withOpacity(0.18);
      canvas.drawCircle(Offset(p.x, p.y), 24, _playerHaloPaint);

      // Ship fill and rim
      _playerPaint.color = p.color.withOpacity(0.85);
      canvas.drawCircle(Offset(p.x, p.y), 13, _playerPaint);
      _playerRimPaint.color = p.color;
      canvas.drawCircle(Offset(p.x, p.y), 13, _playerRimPaint);
      canvas.drawCircle(Offset(p.x, p.y), 5, _playerCorePaint);

      // Lives and stats indicators above head
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x - 20, p.y - 28, 40, 4.5),
          const Radius.circular(2),
        ),
        _playerHpBarBg,
      );

      final double hpPercent = (p.health / p.maxHealth).clamp(0.0, 1.0);
      _playerHpBarFill.color = hpPercent > 0.4 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x - 20, p.y - 28, 40 * hpPercent, 4.5),
          const Radius.circular(2),
        ),
        _playerHpBarFill,
      );

      // Aim Line & Reticle
      if (p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
        _laserPaint.color = p.color.withOpacity(0.2);
        canvas.drawLine(Offset(p.x, p.y), p.aimPosition, _laserPaint);
        _crosshairPaint.color = p.color;
        canvas.drawCircle(p.aimPosition, 5.0, _crosshairPaint);
        canvas.drawCircle(p.aimPosition, 1.5, _crosshairDotPaint);
      } else {
        // Subtle dotted ring or pointer in direction of aim
        _laserPaint.color = p.color.withOpacity(0.08);
        canvas.drawCircle(Offset(p.x, p.y), 60.0, _laserPaint);
      }

      // Draw active player lives as tiny dots above health bar
      for (int i = 0; i < p.lives; i++) {
        canvas.drawCircle(Offset(p.x - 14 + (i * 14), p.y - 36), 2.5, Paint()..color = p.color);
      }
    }

    // Arena walls
    canvas.drawRect(Rect.fromLTWH(0, 0, _NeonSurvivalEngineState.arenaWidth, _NeonSurvivalEngineState.arenaHeight), _borderPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, _NeonSurvivalEngineState.arenaWidth, _NeonSurvivalEngineState.arenaHeight), _neonPaint);

    // Spawning Portals
    _drawPortal(canvas, _NeonSurvivalEngineState.arenaWidth / 2, 0, false, state._topDoorGlow);
    _drawPortal(canvas, _NeonSurvivalEngineState.arenaWidth / 2, _NeonSurvivalEngineState.arenaHeight, false, state._bottomDoorGlow);
    _drawPortal(canvas, 0, _NeonSurvivalEngineState.arenaHeight / 2, true, state._leftDoorGlow);
    _drawPortal(canvas, _NeonSurvivalEngineState.arenaWidth, _NeonSurvivalEngineState.arenaHeight / 2, true, state._rightDoorGlow);

    canvas.restore(); // Centroid camera scale/translation

    // Game Over fixed Screen overlay
    if (state._isGameOver) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 800.0, 600.0), _bgOverlayPaint);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'MISSION FAILED',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            shadows: [
              Shadow(
                color: Color(0xFFEF4444),
                blurRadius: 15,
              )
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((800.0 - textPainter.width) / 2, 220.0));

      final scorePainter = TextPainter(
        text: TextSpan(
          text: 'COMBINED SCORE: ${state._players.fold(0, (sum, p) => sum + p.score)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      scorePainter.layout();
      scorePainter.paint(canvas, Offset((800.0 - scorePainter.width) / 2, 300.0));
    }

    canvas.restore(); // Frame boundaries
  }

  void _drawPortal(Canvas canvas, double x, double y, bool isVertical, double glowValue) {
    final double w = isVertical ? 8.0 : 120.0;
    final double h = isVertical ? 120.0 : 8.0;
    final rect = Rect.fromCenter(center: Offset(x, y), width: w, height: h);

    canvas.drawRect(rect, _portalBgPaint);
    _portalGlowPaint.color = const Color(0xFFA855F7).withOpacity(0.2 + glowValue * 0.8);
    _portalGlowPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 + glowValue * 7.0);
    canvas.drawRect(rect, _portalGlowPaint);
    canvas.drawRect(rect, _portalLinePaint);
  }

  void _drawSingleBullet(Canvas canvas, double bx, double by, bool isEnemy, Color? playerColor) {
    final Color bulletColor = isEnemy ? const Color(0xFFEC4899) : (playerColor ?? const Color(0xFF06B6D4));
    _bulletPaint.color = bulletColor;
    _bulletGlowPaint.color = bulletColor.withOpacity(0.35);
    _bulletGlowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(bx, by), 8.0, _bulletGlowPaint);
    canvas.drawCircle(Offset(bx, by), 4.0, _bulletPaint);
  }

  void _drawSingleEnemy(Canvas canvas, double ex, double ey, double hp, double maxHp, String type) {
    Color col;
    double rad;

    if (type == 'runner') {
      col = const Color(0xFF10B981);
      rad = 12.0;
    } else if (type == 'tank') {
      col = const Color(0xFFF97316);
      rad = 18.0;
    } else {
      col = const Color(0xFFEC4899);
      rad = 14.0;
    }

    _enemyFillPaint.color = col.withOpacity(0.15);
    _enemyStrokePaint.color = col;
    _enemyGlowPaint.color = col.withOpacity(0.22);
    _enemyGlowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(Offset(ex, ey), rad + 2.0, _enemyGlowPaint);

    if (type == 'runner') {
      final p = Path()
        ..moveTo(ex, ey - rad)
        ..lineTo(ex + rad * 0.86, ey + rad * 0.5)
        ..lineTo(ex - rad * 0.86, ey + rad * 0.5)
        ..close();
      canvas.drawPath(p, _enemyFillPaint);
      canvas.drawPath(p, _enemyStrokePaint);
    } else if (type == 'tank') {
      canvas.drawRect(Rect.fromCircle(center: Offset(ex, ey), radius: rad), _enemyFillPaint);
      canvas.drawRect(Rect.fromCircle(center: Offset(ex, ey), radius: rad), _enemyStrokePaint);
    } else {
      canvas.drawCircle(Offset(ex, ey), rad, _enemyFillPaint);
      canvas.drawCircle(Offset(ex, ey), rad, _enemyStrokePaint);
      canvas.drawCircle(Offset(ex, ey), 4, _enemyStrokePaint);
    }

    if (hp < maxHp && hp > 0) {
      canvas.drawRect(Rect.fromLTWH(ex - 15, ey - rad - 9, 30, 3.5), _enemyHpBgPaint);
      _enemyHpFillPaint.color = col;
      canvas.drawRect(Rect.fromLTWH(ex - 15, ey - rad - 9, 30 * (hp / maxHp), 3.5), _enemyHpFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GameEnemy {
  final int id;
  double x;
  double y;
  double health;
  double maxHealth;
  final String type;
  double speed;
  double lastShotTime = 0.0;

  _GameEnemy({
    required this.id,
    required this.x,
    required this.y,
    required this.health,
    required this.maxHealth,
    required this.type,
    required this.speed,
  });
}

class _GameBullet {
  double x;
  double y;
  double vx;
  double vy;
  final bool isEnemy;
  final Player? owner;

  _GameBullet({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isEnemy,
    this.owner,
  });
}

class _VisualParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double life;
  double decay;
  double size;

  _VisualParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
    required this.decay,
    required this.size,
  });
}
