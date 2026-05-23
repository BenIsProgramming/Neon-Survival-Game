import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'input_profile.dart';
import 'leaderboard.dart';
import 'dart:js' as js;

class Player {
  final int id;
  final String name;
  Color color;
  final InputProfile inputProfile;

  double x;
  double y;
  double health;
  double maxHealth;
  int score;
  int lives;
  bool isAlive;

  double invulnTimer = 0.0;
  bool get isInvulnerable => invulnTimer > 0.0;

  double lastShotTime = 0.0;
  Offset aimPosition = const Offset(0, 0);
  Offset lastMouseViewportPos = const Offset(400, 300);

  String activeWeapon = 'blaster'; // 'blaster', 'spread', 'laser', 'plasma'
  int ammo = 0;

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
    invulnTimer = 0.0;
    activeWeapon = 'blaster';
    ammo = 0;
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
  final double sfxVolume;
  final bool screenShakeEnabled;
  final String colorblindFilter;
  final bool isHardcore;
  final String mapType;
  final void Function(int targetPanel) onQuit;

  const NeonSurvivalEngine({
    Key? key,
    required this.initialPlayers,
    required this.difficulty,
    required this.sfxVolume,
    required this.screenShakeEnabled,
    required this.colorblindFilter,
    required this.isHardcore,
    required this.mapType,
    required this.onQuit,
  }) : super(key: key);

  @override
  State<NeonSurvivalEngine> createState() => _NeonSurvivalEngineState();
}

class _NeonSurvivalEngineState extends State<NeonSurvivalEngine> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final RepaintNotifier _repaintNotifier = RepaintNotifier();
  Duration _lastDuration = Duration.zero;

  // Mid-game Settings state
  late double _activeSfxVolume;
  late bool _activeScreenShake;
  late String _activeColorblindFilter;

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
  final List<_GamePickup> _pickups = [];
  final List<Rect> _obstacles = [];
  final List<_VisualParticle> _particles = [];
  final Random _random = Random();

  int _enemyIdCounter = 0;
  int _pickupIdCounter = 0;
  double _elapsedTime = 0.0;
  double _lastSpawnTime = 0.0;
  double _lastPickupSpawnTime = 0.0; // spawn timer tracker for random pickups
  bool _isGameOver = false;
  bool _isPaused = false;
  bool _showSettingsInPause = false;

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
  bool _isPrimaryMousePressed = false;

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
    
    // Copy parameters from main menu settings
    _activeSfxVolume = widget.sfxVolume;
    _activeScreenShake = widget.screenShakeEnabled;
    _activeColorblindFilter = widget.colorblindFilter;

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
    _obstacles.clear();
    if (widget.mapType == 'pillars') {
      _obstacles.add(const Rect.fromLTWH(350, 250, 120, 120));
      _obstacles.add(const Rect.fromLTWH(1130, 250, 120, 120));
      _obstacles.add(const Rect.fromLTWH(350, 830, 120, 120));
      _obstacles.add(const Rect.fromLTWH(1130, 830, 120, 120));
    } else if (widget.mapType == 'cross') {
      _obstacles.add(const Rect.fromLTWH(740, 100, 120, 300));
      _obstacles.add(const Rect.fromLTWH(740, 800, 120, 300));
      _obstacles.add(const Rect.fromLTWH(150, 540, 300, 120));
      _obstacles.add(const Rect.fromLTWH(1150, 540, 300, 120));
    }
    _isGameOver = false;
    _isPaused = false;
    _showSettingsInPause = false;
    _enemies.clear();
    _bullets.clear();
    _pickups.clear();
    _particles.clear();
    _elapsedTime = 0.0;
    _lastSpawnTime = 0.0;
    _lastPickupSpawnTime = 0.0;
    _enemyIdCounter = 0;
    _pickupIdCounter = 0;
    _cameraX = (arenaWidth / 2) - 400.0;
    _cameraY = (arenaHeight / 2) - 300.0;
    _zoomLevel = 1.0;
  }

  Offset _resolveObstacleCollision(double cx, double cy, double radius) {
    double newX = cx;
    double newY = cy;

    for (final rect in _obstacles) {
      double px = newX.clamp(rect.left, rect.right);
      double py = newY.clamp(rect.top, rect.bottom);

      double dx = newX - px;
      double dy = newY - py;
      double dist = sqrt(dx * dx + dy * dy);

      if (dist < radius) {
        if (dist > 0) {
          double nx = dx / dist;
          double ny = dy / dist;
          double pen = radius - dist;
          newX += nx * pen;
          newY += ny * pen;
        } else {
          double dl = newX - rect.left;
          double dr = rect.right - newX;
          double dt = newY - rect.top;
          double db = rect.bottom - newY;
          double minDist = min(min(dl, dr), min(dt, db));
          if (minDist == dl) {
            newX = rect.left - radius;
          } else if (minDist == dr) {
            newX = rect.right + radius;
          } else if (minDist == dt) {
            newY = rect.top - radius;
          } else {
            newY = rect.bottom + radius;
          }
        }
      }
    }
    return Offset(newX, newY);
  }

  // Synthesized audio helper
  void _playSfx(String jsFunctionName) {
    if (kIsWeb) {
      try {
        js.context.callMethod(jsFunctionName, [_activeSfxVolume]);
      } catch (_) {}
    }
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

    // Skip physical game loops when paused
    if (!_isPaused) {
      _updatePhysics(dt);
      _updateParticles(dt);
      _updateCamera();
    }

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

      // Handle invulnerability countdown timer
      if (p.invulnTimer > 0.0) {
        p.invulnTimer -= dt;
      }

      double dx = 0.0;
      double dy = 0.0;

      // Handle keyboard move inputs
      if (_pressedKeys.contains(p.inputProfile.moveUp)) dy -= 1.0;
      if (_pressedKeys.contains(p.inputProfile.moveDown)) dy += 1.0;
      if (_pressedKeys.contains(p.inputProfile.moveLeft)) dx -= 1.0;
      if (_pressedKeys.contains(p.inputProfile.moveRight)) dx += 1.0;

      if (dx != 0.0 || dy != 0.0) {
        double mag = sqrt(dx * dx + dy * dy);
        double baseSpeed = 250.0;
        
        // Speed up player by 1.5x during invulnerability (disabled in hardcore mode)
        double speed = (p.isInvulnerable && !widget.isHardcore) ? baseSpeed * 1.5 : baseSpeed;
        
        dx = (dx / mag) * speed * dt;
        dy = (dy / mag) * speed * dt;
        p.x += dx;
        p.y += dy;

        p.x = p.x.clamp(20.0, arenaWidth - 20.0);
        p.y = p.y.clamp(20.0, arenaHeight - 20.0);

        final resolved = _resolveObstacleCollision(p.x, p.y, 13.0);
        p.x = resolved.dx;
        p.y = resolved.dy;
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
          p.aimPosition = Offset(p.x, p.y - 100.0);
        }
      }

      // Shooting mechanics
      bool wantsToShoot = false;
      if (p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
        if (_pressedKeys.contains(LogicalKeyboardKey.space) || _isPrimaryMousePressed) {
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

      double fireDelay = p.activeWeapon == 'blaster'
          ? 0.22
          : (p.activeWeapon == 'spread'
              ? 0.25
              : (p.activeWeapon == 'laser' ? 0.14 : 0.5));

      if (wantsToShoot && _elapsedTime - p.lastShotTime > fireDelay) {
        p.lastShotTime = _elapsedTime;
        _firePlayerBullet(p);
      }
    }

    if (!anyPlayerAlive) {
      _triggerGameOver();
      return;
    }

    // 2. Clamp players to the camera bounds
    _clampPlayersToViewport();

    // 3. Enemy Spawning Logic
    double baseSpawnInterval = widget.difficulty.toLowerCase() == 'easy' ? 4.0 : (widget.difficulty.toLowerCase() == 'hard' ? 1.8 : 2.8);
    double spawnInterval = max(0.4, baseSpawnInterval - (_elapsedTime * 0.015));
    if (_elapsedTime - _lastSpawnTime > spawnInterval) {
      _lastSpawnTime = _elapsedTime;
      _spawnEnemy();
    }

    // Random Pickup Spawning Over Time
    if (_elapsedTime - _lastPickupSpawnTime > 13.0) {
      _lastPickupSpawnTime = _elapsedTime;
      double px = 120.0 + _random.nextDouble() * (arenaWidth - 240.0);
      double py = 120.0 + _random.nextDouble() * (arenaHeight - 240.0);
      _spawnPickupAt(px, py);
    }

    // 4b. Update Pickups
    for (int i = _pickups.length - 1; i >= 0; i--) {
      final p = _pickups[i];
      p.timer -= dt;
      if (p.timer <= 0.0) {
        _pickups.removeAt(i);
        continue;
      }

      for (final player in _players) {
        if (!player.isAlive) continue;
        double dx = p.x - player.x;
        double dy = p.y - player.y;
        double dist = sqrt(dx * dx + dy * dy);
        
        if (dist < 25.0) {
          if (p.type == 'health') {
            if (player.health >= player.maxHealth) continue; 
            player.health = min(player.maxHealth, player.health + 40.0);
            _playSfx('playHit'); 
          } else if (p.type == 'life') {
            if (player.lives >= 5) continue; 
            player.lives++;
            _playSfx('playPowerUp');
          } else {
            player.activeWeapon = p.type;
            player.ammo = p.ammoAmount;
            _playSfx('playPowerUp');
          }
          _spawnLocalExplosion(p.x, p.y, p.type == 'health' ? Colors.greenAccent : (p.type == 'life' ? Colors.pinkAccent : Colors.yellowAccent), count: 12);
          _pickups.removeAt(i);
          break;
        }
      }
    }

    // 4. Update Bullets
    for (int i = _bullets.length - 1; i >= 0; i--) {
      final b = _bullets[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;

      bool hitWall = false;
      for (final rect in _obstacles) {
        if (rect.contains(Offset(b.x, b.y))) {
          hitWall = true;
          break;
        }
      }

      if (hitWall) {
        if (b.type == 'plasma') {
          _spawnLocalExplosion(b.x, b.y, Colors.orangeAccent, count: 18);
          _playSfx('playExplosion');
          for (int k = _enemies.length - 1; k >= 0; k--) {
            final targetEnemy = _enemies[k];
            double pdx = b.x - targetEnemy.x;
            double pdy = b.y - targetEnemy.y;
            double pdist = sqrt(pdx * pdx + pdy * pdy);
            double enemyRadius = targetEnemy.type == 'tank' ? 18.0 : 12.0;
            if (pdist < 65.0 + enemyRadius) {
              targetEnemy.health -= 4.0;
              if (targetEnemy.health <= 0) {
                _enemies.removeAt(k);
                _playSfx('playExplosion');
                if (b.owner != null) {
                  b.owner!.score += targetEnemy.type == 'tank' ? 50 : (targetEnemy.type == 'shooter' ? 30 : 10);
                  _rollPickupDrop(targetEnemy.x, targetEnemy.y, targetEnemy.type);
                }
                _spawnLocalExplosion(targetEnemy.x, targetEnemy.y, _rainbowColors[_random.nextInt(_rainbowColors.length)], count: 14);
              }
            }
          }
        } else {
          _spawnLocalExplosion(b.x, b.y, b.isEnemy ? Colors.redAccent : Colors.cyanAccent, count: 4);
          _playSfx('playHit');
        }
        _bullets.removeAt(i);
        continue;
      }

      if (b.x < -50 || b.x > arenaWidth + 50 || b.y < -50 || b.y > arenaHeight + 50) {
        _bullets.removeAt(i);
      }
    }

    // 5. Update Enemies
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

        if (_elapsedTime - e.lastShotTime > 1.8) {
          e.lastShotTime = _elapsedTime;
          _fireEnemyBullet(e.x, e.y, target.x, target.y);
          _playSfx('playEnemyLaser'); // Play opponent firing sound
        }
      } else {
        e.x += edx * e.speed * dt;
        e.y += edy * e.speed * dt;
      }

      if (e.x >= 0.0 && e.x <= arenaWidth && e.y >= 0.0 && e.y <= arenaHeight) {
        e.x = e.x.clamp(12.0, arenaWidth - 12.0);
        e.y = e.y.clamp(12.0, arenaHeight - 12.0);
      }

      final enemyRadius = e.type == 'tank' ? 18.0 : 12.0;
      final resolved = _resolveObstacleCollision(e.x, e.y, enemyRadius);
      e.x = resolved.dx;
      e.y = resolved.dy;

      double colDist = e.type == 'tank' ? 24.0 : 16.0;
      if (dist < colDist) {
        // Skip damage calculation if player has active invulnerability
        if (target.isInvulnerable && !widget.isHardcore) continue;

        if (widget.isHardcore) {
          // Hardcore: collision touch is immediate death
          _killPlayer(target);
        } else {
          double damage = e.type == 'tank' ? 25.0 : 12.0;
          target.health = max(0.0, target.health - damage * dt * 5.0);
          
          if (_random.nextDouble() < 0.08) {
            _playSfx('playHit');
          }
          
          if (target.health <= 0) {
            _killPlayer(target);
          }
        }
      }
    }

    // 6. Check Bullet Collisions
    for (int bi = _bullets.length - 1; bi >= 0; bi--) {
      final b = _bullets[bi];

      if (b.isEnemy) {
        for (final p in _players) {
          if (!p.isAlive) continue;
          if (p.isInvulnerable && !widget.isHardcore) continue;

          double dx = b.x - p.x;
          double dy = b.y - p.y;
          double dist = sqrt(dx * dx + dy * dy);
          if (dist < 16.0) {
            _bullets.removeAt(bi);
            _spawnLocalExplosion(b.x, b.y, Colors.redAccent, count: 5);

            if (widget.isHardcore) {
              // Hardcore: one hit death
              _killPlayer(p);
            } else {
              p.health = max(0.0, p.health - 12.0);
              _playSfx('playHit');
              if (p.health <= 0) {
                _killPlayer(p);
              }
            }
            break;
          }
        }
      } else {
        for (int ei = _enemies.length - 1; ei >= 0; ei--) {
          final e = _enemies[ei];
          
          if (b.type == 'laser' && b.hitEnemyIds.contains(e.id)) continue;

          double dx = b.x - e.x;
          double dy = b.y - e.y;
          double dist = sqrt(dx * dx + dy * dy);
          double radius = e.type == 'tank' ? 18.0 : 12.0;

          if (dist < radius + (b.size - 4.0)) {
            if (b.type == 'laser') {
              b.hitEnemyIds.add(e.id);
              e.health -= 1.0;
              _spawnLocalExplosion(b.x, b.y, Colors.cyanAccent, count: 2);
              _playSfx('playHit');
            } else if (b.type == 'plasma') {
              _bullets.removeAt(bi);
              _spawnLocalExplosion(b.x, b.y, Colors.orangeAccent, count: 18);
              _playSfx('playExplosion');

              for (int k = _enemies.length - 1; k >= 0; k--) {
                final targetEnemy = _enemies[k];
                double pdx = b.x - targetEnemy.x;
                double pdy = b.y - targetEnemy.y;
                double pdist = sqrt(pdx * pdx + pdy * pdy);
                double enemyRadius = targetEnemy.type == 'tank' ? 18.0 : 12.0;
                if (pdist < 65.0 + enemyRadius) {
                  targetEnemy.health -= 4.0;
                  if (targetEnemy.health <= 0) {
                    _enemies.removeAt(k);
                    _playSfx('playExplosion');
                    if (b.owner != null) {
                      b.owner!.score += targetEnemy.type == 'tank' ? 50 : (targetEnemy.type == 'shooter' ? 30 : 10);
                      _rollPickupDrop(targetEnemy.x, targetEnemy.y, targetEnemy.type);
                    }
                    _spawnLocalExplosion(targetEnemy.x, targetEnemy.y, _rainbowColors[_random.nextInt(_rainbowColors.length)], count: 14);
                  }
                }
              }
              break; 
            } else {
              e.health -= 1.0;
              _bullets.removeAt(bi);
              _spawnLocalExplosion(b.x, b.y, _rainbowColors[_random.nextInt(_rainbowColors.length)], count: 4);
              _playSfx('playHit');
            }

            if (b.type != 'plasma' && e.health <= 0) {
              _enemies.removeAt(ei);
              _playSfx('playExplosion');
              if (b.owner != null) {
                b.owner!.score += e.type == 'tank' ? 50 : (e.type == 'shooter' ? 30 : 10);
                _rollPickupDrop(e.x, e.y, e.type);
              }
              _spawnLocalExplosion(e.x, e.y, _rainbowColors[_random.nextInt(_rainbowColors.length)], count: 18);
            }

            if (b.type != 'laser') {
              break; 
            }
          }
        }
      }
    }
  }

  void _updateCamera() {
    final alive = _players.where((p) => p.isAlive).toList();
    if (alive.isEmpty) return;

    double sumX = 0;
    double sumY = 0;
    for (final p in alive) {
      sumX += p.x;
      sumY += p.y;
    }
    double targetCamX = (sumX / alive.length) - 400.0;
    double targetCamY = (sumY / alive.length) - 300.0;

    double maxSpread = 0.0;
    for (int i = 0; i < alive.length; i++) {
      for (int j = i + 1; j < alive.length; j++) {
        double d = sqrt(pow(alive[i].x - alive[j].x, 2) + pow(alive[i].y - alive[j].y, 2));
        if (d > maxSpread) maxSpread = d;
      }
    }

    double targetZoom = 1.0;
    if (alive.length > 1) {
      double factor = (maxSpread - 100.0) / 600.0;
      factor = factor.clamp(0.0, 1.0);
      targetZoom = 1.2 - (factor * 0.45);
    }

    _cameraX += (targetCamX - _cameraX) * 0.12;
    _cameraY += (targetCamY - _cameraY) * 0.12;
    _zoomLevel += (targetZoom - _zoomLevel) * 0.08;

    _cameraX = _cameraX.clamp(0.0, arenaWidth - 800.0);
    _cameraY = _cameraY.clamp(0.0, arenaHeight - 600.0);
  }

  void _clampPlayersToViewport() {
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
    double minDist = 360.0;
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

    double baseAngle = atan2(dy, dx);

    if (p.activeWeapon == 'spread') {
      double speed = 520.0;
      final angles = [-15.0 * pi / 180.0, 0.0, 15.0 * pi / 180.0];
      for (final offset in angles) {
        double angle = baseAngle + offset;
        _bullets.add(_GameBullet(
          x: p.x + cos(angle) * 16.0,
          y: p.y + sin(angle) * 16.0,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          isEnemy: false,
          owner: p,
          type: 'spread',
          size: 4.0,
        ));
      }
      _playSfx('playLaser');
      _spawnLocalExplosion(p.x + dx * 16.0, p.y + dy * 16.0, p.color, count: 3);
    } else if (p.activeWeapon == 'laser') {
      double speed = 900.0;
      _bullets.add(_GameBullet(
        x: p.x + dx * 16.0,
        y: p.y + dy * 16.0,
        vx: dx * speed,
        vy: dy * speed,
        isEnemy: false,
        owner: p,
        type: 'laser',
        size: 3.5,
      ));
      _playSfx('playLaser');
      _spawnLocalExplosion(p.x + dx * 16.0, p.y + dy * 16.0, Colors.blueAccent, count: 2);
    } else if (p.activeWeapon == 'plasma') {
      double speed = 330.0;
      _bullets.add(_GameBullet(
        x: p.x + dx * 16.0,
        y: p.y + dy * 16.0,
        vx: dx * speed,
        vy: dy * speed,
        isEnemy: false,
        owner: p,
        type: 'plasma',
        size: 13.0,
      ));
      _playSfx('playExplosion');
      _spawnLocalExplosion(p.x + dx * 16.0, p.y + dy * 16.0, Colors.orangeAccent, count: 4);
    } else {
      // Default blaster
      double speed = 500.0;
      _bullets.add(_GameBullet(
        x: p.x + dx * 16.0,
        y: p.y + dy * 16.0,
        vx: dx * speed,
        vy: dy * speed,
        isEnemy: false,
        owner: p,
        type: 'blaster',
        size: 4.0,
      ));
      _playSfx('playLaser');
      _spawnLocalExplosion(p.x + dx * 16.0, p.y + dy * 16.0, p.color, count: 2);
    }

    // Ammo management
    if (p.activeWeapon != 'blaster') {
      p.ammo--;
      if (p.ammo <= 0) {
        p.activeWeapon = 'blaster';
        _playSfx('playHit'); // play click / hit sound for out of ammo feedback
      }
    }
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

  void _rollPickupDrop(double x, double y, String enemyType) {
    double roll = _random.nextDouble();
    double threshold = 0.03; 
    if (enemyType == 'shooter') threshold = 0.15;
    else if (enemyType == 'tank') threshold = 0.10;
    
    if (roll < threshold) {
      _spawnPickupAt(x, y);
    }
  }

  void _spawnPickupAt(double x, double y) {
    _pickupIdCounter++;
    final List<String> pool = ['spread', 'laser', 'plasma'];
    
    if (!widget.isHardcore && widget.difficulty.toLowerCase() != 'hard') {
      pool.add('health');
      if (_random.nextDouble() < 0.25) {
        pool.add('life');
      }
    }
    
    final type = pool[_random.nextInt(pool.length)];
    int ammoAmount = 0;
    if (type == 'spread') ammoAmount = 45;
    else if (type == 'laser') ammoAmount = 60;
    else if (type == 'plasma') ammoAmount = 20;

    _pickups.add(_GamePickup(
      id: _pickupIdCounter,
      x: x,
      y: y,
      type: type,
      ammoAmount: ammoAmount,
    ));
    _spawnLocalExplosion(x, y, Colors.white, count: 6);
  }

  void _spawnEnemy() {
    _enemyIdCounter++;
    double x = 0.0;
    double y = 0.0;
    int portalEdge = _random.nextInt(4);

    switch (portalEdge) {
      case 0:
        x = arenaWidth / 2;
        y = -10.0;
        _topDoorGlow = 1.0;
        break;
      case 1:
        x = arenaWidth + 10.0;
        y = arenaHeight / 2;
        _rightDoorGlow = 1.0;
        break;
      case 2:
        x = arenaWidth / 2;
        y = arenaHeight + 10.0;
        _bottomDoorGlow = 1.0;
        break;
      case 3:
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
    _playSfx('playHit'); // subtle warp gate beep
  }

  void _killPlayer(Player p) {
    p.lives--;
    _playSfx('playExplosion');
    _spawnLocalExplosion(p.x, p.y, p.color, count: 25);
    
    if (p.lives > 0) {
      p.health = p.maxHealth;
      // Do NOT reset player coordinates to center of arena. Keep them in action!
      // Give invulnerability grace countdown (unless hardcore is active)
      if (!widget.isHardcore) {
        p.invulnTimer = 3.0; // 3 seconds of invulnerability & speed boost
      }
    } else {
      p.isAlive = false;
    }
  }

  void _triggerGameOver() {
    if (_isGameOver) return;
    _isGameOver = true;
    _playSfx('playGameOver');

    // Calculate score multipliers based on difficulty & hardcore
    double difficultyBase = widget.difficulty.toLowerCase() == 'easy' ? 1.0 : (widget.difficulty.toLowerCase() == 'hard' ? 2.0 : 1.5);
    double multiplier = difficultyBase + (widget.isHardcore ? 1.0 : 0.0);

    // Save multiplied final score locally
    int baseScore = _players.fold(0, (sum, p) => sum + p.score);
    int finalScore = (baseScore * multiplier).round();
    
    String playerNames = _players.map((p) => p.name).join(' & ');
    LeaderboardManager.saveScore(playerNames, finalScore, _players.length, widget.difficulty, widget.isHardcore);
  }

  void _restartGame() {
    setState(() {
      _setupInitialPlayerStats();
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      _showSettingsInPause = false;
    });
    _playSfx('playHit');
  }

  Future<void> _saveMidGameSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('neon_settings_sfx_volume', _activeSfxVolume);
    await prefs.setBool('neon_settings_screen_shake', _activeScreenShake);
    await prefs.setString('neon_settings_colorblind_filter', _activeColorblindFilter);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (!_isGameOver) {
          _togglePause();
        }
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.gameButtonStart || event.logicalKey == LogicalKeyboardKey.select) {
        if (!_isGameOver) {
          _togglePause();
        }
        return;
      }

      if (_isGameOver || _isPaused) return;

      _pressedKeys.add(event.logicalKey);
      
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
        child: Stack(
          children: [
            Column(
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
                            if (_isGameOver || _isPaused) return;
                            final RenderBox box = context.findRenderObject() as RenderBox;
                            final localPos = box.globalToLocal(e.position);
                            double canvasLeft = (constraints.maxWidth - w) / 2;
                            double canvasTop = (constraints.maxHeight - h) / 2;

                            double viewportX = (localPos.dx - canvasLeft) / scale;
                            double viewportY = (localPos.dy - canvasTop) / scale;

                            for (final p in _players) {
                              if (p.isAlive && p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
                                p.lastMouseViewportPos = Offset(viewportX, viewportY);
                              }
                            }
                            _repaintNotifier.triggerRepaint();
                          },
                          child: GestureDetector(
                            onTapDown: (_) {
                              if (_isGameOver || _isPaused) return;
                              setState(() {
                                _isPrimaryMousePressed = true;
                              });
                              for (final p in _players) {
                                if (p.isAlive && p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
                                  double fireDelay = p.activeWeapon == 'blaster'
                                      ? 0.22
                                      : (p.activeWeapon == 'spread'
                                          ? 0.25
                                          : (p.activeWeapon == 'laser' ? 0.14 : 0.5));
                                  if (_elapsedTime - p.lastShotTime > fireDelay) {
                                    p.lastShotTime = _elapsedTime;
                                    _firePlayerBullet(p);
                                  }
                                }
                              }
                            },
                            onTapUp: (_) {
                              setState(() {
                                _isPrimaryMousePressed = false;
                              });
                            },
                            onTapCancel: () {
                              setState(() {
                                _isPrimaryMousePressed = false;
                              });
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

            if (_isPaused) _buildPauseOverlay(),
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
            icon: const Icon(Icons.pause, color: Colors.white70),
            onPressed: () {
              if (!_isGameOver) {
                _togglePause();
              }
            },
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
                'MODE: ${widget.difficulty.toUpperCase()}${widget.isHardcore ? " + HARDCORE" : ""}',
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
    int baseScore = _players.fold(0, (sum, p) => sum + p.score);
    double difficultyBase = widget.difficulty.toLowerCase() == 'easy' ? 1.0 : (widget.difficulty.toLowerCase() == 'hard' ? 2.0 : 1.5);
    double multiplier = difficultyBase + (widget.isHardcore ? 1.0 : 0.0);
    int finalScore = (baseScore * multiplier).round();

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
          Expanded(
            child: Column(
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Score: $baseScore x ${multiplier.toStringAsFixed(1)} (Difficulty Bonus) = $finalScore pts  •  Survived: ${_elapsedTime.toStringAsFixed(1)} seconds',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => widget.onQuit(0),
                child: const Text('MAIN MENU', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => widget.onQuit(2),
                child: const Text('LEADERBOARD', style: TextStyle(color: Colors.amberAccent)),
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

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1324),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1E293B), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 1,
                )
              ],
            ),
            child: _showSettingsInPause ? _buildPauseSettingsView() : _buildPauseMainView(),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseMainView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'MISSION PAUSED',
          style: TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            shadows: [Shadow(color: Color(0xFF38BDF8), blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 32),
        _buildPauseButton('RESUME', _togglePause, const Color(0xFF10B981)),
        const SizedBox(height: 14),
        _buildPauseButton('SETTINGS', () {
          setState(() {
            _showSettingsInPause = true;
          });
        }, const Color(0xFF06B6D4)),
        const SizedBox(height: 14),
        _buildPauseButton('ABANDON MISSION', () => widget.onQuit(0), const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildPauseSettingsView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'MID-GAME SETTINGS',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SFX VOLUME', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('${(_activeSfxVolume * 100).round()}%', style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11)),
              ],
            ),
            Slider(
              value: _activeSfxVolume,
              onChanged: (val) {
                setState(() {
                  _activeSfxVolume = val;
                });
                _playSfx('playLaser');
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('SCREEN SHAKE', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Switch(
              value: _activeScreenShake,
              onChanged: (val) {
                setState(() {
                  _activeScreenShake = val;
                });
              },
              activeColor: const Color(0xFF06B6D4),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('COLORBLIND FILTER', style: TextStyle(color: Colors.white70, fontSize: 12)),
            DropdownButton<String>(
              value: _activeColorblindFilter,
              dropdownColor: const Color(0xFF0C1324),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _activeColorblindFilter = val;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'none', child: Text('NONE')),
                DropdownMenuItem(value: 'protanopia', child: Text('PROTANOPIA')),
                DropdownMenuItem(value: 'deuteranopia', child: Text('DEUTERANOPIA')),
                DropdownMenuItem(value: 'tritanopia', child: Text('TRITANOPIA')),
              ],
            )
          ],
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                _saveMidGameSettings();
                setState(() {
                  _showSettingsInPause = false;
                });
              },
              child: const Text('BACK', style: TextStyle(color: Colors.white60)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPauseButton(String text, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: 220,
      height: 42,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF060A13),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13),
        ),
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

  Color _getFilteredColor(Color original) {
    final filter = state._activeColorblindFilter;
    if (filter == 'none') return original;

    if (filter == 'protanopia') {
      if (original.value == 0xFFEF4444 || original == Colors.red || original == Colors.redAccent) {
        return const Color(0xFF3B82F6);
      }
      if (original.value == 0xFFEC4899 || original == Colors.pink || original == Colors.pinkAccent) {
        return const Color(0xFFF59E0B);
      }
    }

    if (filter == 'deuteranopia') {
      if (original.value == 0xFF10B981 || original == Colors.green || original == Colors.greenAccent) {
        return const Color(0xFF3B82F6);
      }
    }

    if (filter == 'tritanopia') {
      if (original.value == 0xFF06B6D4 || original == Colors.cyan || original == Colors.cyanAccent) {
        return const Color(0xFFEC4899);
      }
    }

    return original;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 800.0, size.height / 600.0);

    canvas.save();
    
    canvas.translate(400.0, 300.0);
    canvas.scale(state._zoomLevel);
    canvas.translate(-400.0, -300.0);

    canvas.translate(-state._cameraX, -state._cameraY);

    _spaceGridPaint.color = const Color(0xFF1E293B).withOpacity(0.2);
    _spaceGridPaint.strokeWidth = 1.0;

    double gridSpacing = 40.0;
    for (double x = 0; x < _NeonSurvivalEngineState.arenaWidth; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, _NeonSurvivalEngineState.arenaHeight), _spaceGridPaint);
    }
    for (double y = 0; y < _NeonSurvivalEngineState.arenaHeight; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(_NeonSurvivalEngineState.arenaWidth, y), _spaceGridPaint);
    }

    for (final p in state._particles) {
      _particlePaint.color = _getFilteredColor(p.color).withOpacity(p.life);
      canvas.drawCircle(Offset(p.x, p.y), p.size * p.life, _particlePaint);
    }

    for (final b in state._bullets) {
      _drawSingleBullet(canvas, b);
    }

    for (final e in state._enemies) {
      _drawSingleEnemy(canvas, e.x, e.y, e.health, e.maxHealth, e.type);
    }

    for (final pk in state._pickups) {
      _drawSinglePickup(canvas, pk);
    }

    for (final p in state._players) {
      if (!p.isAlive) continue;

      // Handle flashing when player has active invulnerability
      if (p.isInvulnerable && !state.widget.isHardcore) {
        if ((state._elapsedTime * 12).floor() % 2 == 0) {
          continue; // skip rendering to flash
        }
      }

      final pColor = _getFilteredColor(p.color);

      _playerHaloPaint.color = pColor.withOpacity(0.18);
      canvas.drawCircle(Offset(p.x, p.y), 24, _playerHaloPaint);

      _playerPaint.color = pColor.withOpacity(0.85);
      canvas.drawCircle(Offset(p.x, p.y), 13, _playerPaint);
      _playerRimPaint.color = pColor;
      canvas.drawCircle(Offset(p.x, p.y), 13, _playerRimPaint);
      canvas.drawCircle(Offset(p.x, p.y), 5, _playerCorePaint);

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

      if (p.inputProfile.deviceType == InputDeviceType.keyboardMouse) {
        _laserPaint.color = pColor.withOpacity(0.2);
        canvas.drawLine(Offset(p.x, p.y), p.aimPosition, _laserPaint);
        _crosshairPaint.color = pColor;
        canvas.drawCircle(p.aimPosition, 5.0, _crosshairPaint);
        canvas.drawCircle(p.aimPosition, 1.5, _crosshairDotPaint);
      } else {
        _laserPaint.color = pColor.withOpacity(0.08);
        canvas.drawCircle(Offset(p.x, p.y), 60.0, _laserPaint);
      }

      for (int i = 0; i < p.lives; i++) {
        canvas.drawCircle(Offset(p.x - 14 + (i * 14), p.y - 36), 2.5, Paint()..color = pColor);
      }

      if (p.activeWeapon != 'blaster') {
        final ammoPainter = TextPainter(
          text: TextSpan(
            text: '${p.activeWeapon.toUpperCase()}:${p.ammo}',
            style: TextStyle(
              color: p.activeWeapon == 'spread'
                  ? const Color(0xFFF59E0B)
                  : (p.activeWeapon == 'laser' ? const Color(0xFF06B6D4) : const Color(0xFFEC4899)),
              fontSize: 8,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        ammoPainter.layout();
        ammoPainter.paint(canvas, Offset(p.x - ammoPainter.width / 2, p.y + 20));
      }
    }

    final Paint obstacleFillPaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.95)
      ..style = PaintingStyle.fill;
    final Paint obstacleBorderPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final Paint obstacleNeonPaint = Paint()
      ..color = _getFilteredColor(const Color(0xFF06B6D4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final rect in state._obstacles) {
      canvas.drawRect(rect, obstacleFillPaint);
      canvas.drawRect(rect, obstacleBorderPaint);
      canvas.drawRect(rect.deflate(2.0), obstacleNeonPaint);
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, _NeonSurvivalEngineState.arenaWidth, _NeonSurvivalEngineState.arenaHeight), _borderPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, _NeonSurvivalEngineState.arenaWidth, _NeonSurvivalEngineState.arenaHeight), _neonPaint);

    _drawPortal(canvas, _NeonSurvivalEngineState.arenaWidth / 2, 0, false, state._topDoorGlow);
    _drawPortal(canvas, _NeonSurvivalEngineState.arenaWidth / 2, _NeonSurvivalEngineState.arenaHeight, false, state._bottomDoorGlow);
    _drawPortal(canvas, 0, _NeonSurvivalEngineState.arenaHeight / 2, true, state._leftDoorGlow);
    _drawPortal(canvas, _NeonSurvivalEngineState.arenaWidth, _NeonSurvivalEngineState.arenaHeight / 2, true, state._rightDoorGlow);

    canvas.restore();

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
      textPainter.paint(canvas, Offset((800.0 - textPainter.width) / 2, 210.0));

      // Draw Multiplier Score Breakdown details
      double difficultyBase = state.widget.difficulty.toLowerCase() == 'easy' ? 1.0 : (state.widget.difficulty.toLowerCase() == 'hard' ? 2.0 : 1.5);
      double multiplier = difficultyBase + (state.widget.isHardcore ? 1.0 : 0.0);
      int baseScore = state._players.fold(0, (sum, p) => sum + p.score);
      int finalScore = (baseScore * multiplier).round();

      final scorePainter = TextPainter(
        text: TextSpan(
          text: 'FINAL SCORE: $finalScore',
          style: const TextStyle(
            color: Colors.amberAccent,
            fontSize: 22,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      scorePainter.layout();
      scorePainter.paint(canvas, Offset((800.0 - scorePainter.width) / 2, 280.0));

      final breakdownText = state.widget.isHardcore
          ? 'Base Score: $baseScore x ${multiplier.toStringAsFixed(1)} (${state.widget.difficulty.toUpperCase()} + HARDCORE)'
          : 'Base Score: $baseScore x ${multiplier.toStringAsFixed(1)} (${state.widget.difficulty.toUpperCase()})';
      
      final breakdownPainter = TextPainter(
        text: TextSpan(
          text: breakdownText,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      breakdownPainter.layout();
      breakdownPainter.paint(canvas, Offset((800.0 - breakdownPainter.width) / 2, 320.0));
    }

    canvas.restore();
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

  void _drawSingleBullet(Canvas canvas, _GameBullet b) {
    final Color bulletColor = b.isEnemy ? const Color(0xFFEC4899) : (b.owner?.color ?? const Color(0xFF06B6D4));
    final Color shiftedColor = _getFilteredColor(bulletColor);
    
    _bulletPaint.color = shiftedColor;
    _bulletGlowPaint.color = shiftedColor.withOpacity(0.35);
    _bulletGlowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(b.x, b.y), b.size * 2.0, _bulletGlowPaint);
    canvas.drawCircle(Offset(b.x, b.y), b.size, _bulletPaint);
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

    final Color shiftedColor = _getFilteredColor(col);

    _enemyFillPaint.color = shiftedColor.withOpacity(0.15);
    _enemyStrokePaint.color = shiftedColor;
    _enemyGlowPaint.color = shiftedColor.withOpacity(0.22);
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
      _enemyHpFillPaint.color = shiftedColor;
      canvas.drawRect(Rect.fromLTWH(ex - 15, ey - rad - 9, 30 * (hp / maxHp), 3.5), _enemyHpFillPaint);
    }
  }

  void _drawSinglePickup(Canvas canvas, _GamePickup pk) {
    if (pk.timer <= 3.0 && (pk.timer * 10).floor() % 2 == 0) {
      return; 
    }

    Color col;
    if (pk.type == 'health') {
      col = const Color(0xFF10B981); 
    } else if (pk.type == 'life') {
      col = const Color(0xFFEC4899); 
    } else if (pk.type == 'spread') {
      col = const Color(0xFFF59E0B); 
    } else if (pk.type == 'laser') {
      col = const Color(0xFF06B6D4); 
    } else {
      col = const Color(0xFFD946EF); 
    }

    final Color shiftedColor = _getFilteredColor(col);
    final Paint pFill = Paint()
      ..color = shiftedColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final Paint pStroke = Paint()
      ..color = shiftedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final Paint pGlow = Paint()
      ..color = shiftedColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    double bounce = sin(state._elapsedTime * 4.0 + pk.id) * 3.0;
    double px = pk.x;
    double py = pk.y + bounce;

    canvas.drawCircle(Offset(px, py), 16.0, pGlow);

    if (pk.type == 'health') {
      final rectH = Rect.fromLTWH(px - 10, py - 3, 20, 6);
      final rectV = Rect.fromLTWH(px - 3, py - 10, 6, 20);
      canvas.drawRect(rectH, pFill);
      canvas.drawRect(rectH, pStroke);
      canvas.drawRect(rectV, pFill);
      canvas.drawRect(rectV, pStroke);
    } else if (pk.type == 'life') {
      final path = Path()
        ..moveTo(px, py - 6)
        ..cubicTo(px - 6, py - 13, px - 14, py - 7, px - 11, py)
        ..lineTo(px, py + 9)
        ..lineTo(px + 11, py)
        ..cubicTo(px + 14, py - 7, px + 6, py - 13, px, py - 6)
        ..close();
      canvas.drawPath(path, pFill);
      canvas.drawPath(path, pStroke);
    } else if (pk.type == 'spread') {
      final path = Path()
        ..moveTo(px, py - 10)
        ..lineTo(px + 9, py + 8)
        ..lineTo(px - 9, py + 8)
        ..close();
      canvas.drawPath(path, pFill);
      canvas.drawPath(path, pStroke);
      canvas.drawCircle(Offset(px - 6, py + 3), 1.5, pStroke);
      canvas.drawCircle(Offset(px, py - 3), 1.5, pStroke);
      canvas.drawCircle(Offset(px + 6, py + 3), 1.5, pStroke);
    } else if (pk.type == 'laser') {
      canvas.drawRect(Rect.fromLTWH(px - 7, py - 9, 4, 18), pFill);
      canvas.drawRect(Rect.fromLTWH(px - 7, py - 9, 4, 18), pStroke);
      canvas.drawRect(Rect.fromLTWH(px + 3, py - 9, 4, 18), pFill);
      canvas.drawRect(Rect.fromLTWH(px + 3, py - 9, 4, 18), pStroke);
    } else {
      canvas.drawCircle(Offset(px, py), 10.0, pFill);
      canvas.drawCircle(Offset(px, py), 10.0, pStroke);
      canvas.drawCircle(Offset(px, py), 3.0, pStroke);
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
  final String type; // 'blaster', 'spread', 'laser', 'plasma'
  final Set<int> hitEnemyIds; // Tracks which enemies this piercing laser has already hit
  final double size;

  _GameBullet({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isEnemy,
    this.owner,
    this.type = 'blaster',
    Set<int>? hitEnemyIds,
    this.size = 4.0,
  }) : this.hitEnemyIds = hitEnemyIds ?? {};
}

class _GamePickup {
  final int id;
  double x;
  double y;
  final String type; // 'health', 'life', 'spread', 'laser', 'plasma'
  final int ammoAmount;
  double timer;

  _GamePickup({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
    required this.ammoAmount,
    this.timer = 12.0,
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
