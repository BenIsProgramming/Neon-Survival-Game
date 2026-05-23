import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/input_profile.dart';
import '../game/game_engine.dart';
import '../game/leaderboard.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({Key? key}) : super(key: key);

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _activePanel = 0; // 0: Title, 1: Co-op Setup, 2: Leaderboard, 3: How to Play

  // Lobby Config
  String _difficulty = 'normal';
  final List<bool> _slotsActive = [true, false, false, false];
  final List<String> _playerNames = ['P1_APEX', 'P2_NEON', 'P3_GLOW', 'P4_SPARK'];
  final List<Color> _playerColors = [
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFFEC4899), // Pink
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
  ];
  final List<InputProfile> _inputProfiles = [
    InputProfile.player1Default,
    InputProfile.player2Default,
    InputProfile.player3Default,
    InputProfile.player4Default,
  ];

  // Leaderboard data
  List<ScoreEntry> _highScores = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadHighScores();
  }

  Future<void> _loadHighScores() async {
    final list = await LeaderboardManager.getHighScores();
    setState(() {
      _highScores = list;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startGame() {
    // Collect active players
    final List<Player> activePlayers = [];
    for (int i = 0; i < 4; i++) {
      if (_slotsActive[i]) {
        activePlayers.add(Player(
          id: i + 1,
          name: _playerNames[i].trim().isEmpty ? 'PLAYER ${i+1}' : _playerNames[i].toUpperCase(),
          color: _playerColors[i],
          inputProfile: _inputProfiles[i],
          x: 0,
          y: 0,
        ));
      }
    }

    if (activePlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join at least 1 player to launch mission!'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NeonSurvivalEngine(
          initialPlayers: activePlayers,
          difficulty: _difficulty,
          onQuit: () {
            Navigator.pop(context);
            _loadHighScores();
            setState(() {
              _activePanel = 0; // return to main title screen
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04060C),
      body: Stack(
        children: [
          // Cyberpunk Grid Background Drawing
          Positioned.fill(
            child: CustomPaint(
              painter: _MenuGridPainter(animationValue: _pulseController.value),
            ),
          ),

          // Main Interactive Panels
          Center(
            child: Container(
              width: 750,
              height: 520,
              decoration: BoxDecoration(
                color: const Color(0xFF070B16).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E293B), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.08),
                    blurRadius: 30,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _buildCurrentPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPanel() {
    switch (_activePanel) {
      case 1:
        return _buildCoopSetupPanel();
      case 2:
        return _buildLeaderboardPanel();
      case 3:
        return _buildHowToPlayPanel();
      default:
        return _buildTitlePanel();
    }
  }

  // ==========================================
  // PANEL 0: TITLE SCREEN
  // ==========================================

  Widget _buildTitlePanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            double glow = _pulseController.value * 12.0;
            return Text(
              'NEON SURVIVAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(color: const Color(0xFF06B6D4), blurRadius: glow + 4),
                  Shadow(color: const Color(0xFFEC4899), blurRadius: glow + 10),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          'STANDALONE ARCADE EDITION',
          style: TextStyle(
            color: const Color(0xFF38BDF8).withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.5,
          ),
        ),
        const SizedBox(height: 48),
        _buildMenuButton('LAUNCH MISSION', 1, Colors.cyanAccent),
        const SizedBox(height: 14),
        _buildMenuButton('LEADERBOARD', 2, Colors.amberAccent),
        const SizedBox(height: 14),
        _buildMenuButton('HOW TO PLAY', 3, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildMenuButton(String text, int targetPanel, Color glowColor) {
    return SizedBox(
      width: 250,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: glowColor.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF0C1324),
        ),
        onPressed: () {
          setState(() {
            _activePanel = targetPanel;
          });
        },
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 14,
            shadows: [
              Shadow(color: glowColor.withOpacity(0.6), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PANEL 1: CHARACTER / CO-OP LOBBY CONFIG
  // ==========================================

  Widget _buildCoopSetupPanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => setState(() => _activePanel = 0),
              ),
              const Text(
                'LOBBY CONFIGURATION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),

          // Difficulty Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('DIFFICULTY:  ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              _buildDiffOption('easy', const Color(0xFF10B981)),
              _buildDiffOption('normal', const Color(0xFF06B6D4)),
              _buildDiffOption('hard', const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 20),

          // 4 Player Slots Configuration
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => _buildPlayerSlot(index)),
            ),
          ),
          const SizedBox(height: 24),

          // Launch Button
          SizedBox(
            width: 320,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 8,
              ),
              onPressed: _startGame,
              child: const Text(
                'LAUNCH SHIP INTO HYPERSPACE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffOption(String diff, Color activeColor) {
    bool isSelected = _difficulty == diff;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ChoiceChip(
        label: Text(diff.toUpperCase()),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _difficulty = diff);
        },
        selectedColor: activeColor.withOpacity(0.35),
        backgroundColor: const Color(0xFF0C1324),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isSelected ? activeColor : const Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(int index) {
    bool active = _slotsActive[index];
    Color pColor = _playerColors[index];

    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0D162B) : const Color(0xFF070B13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? pColor.withOpacity(0.8) : const Color(0xFF1E293B),
          width: 1.5,
        ),
        boxShadow: active ? [BoxShadow(color: pColor.withOpacity(0.12), blurRadius: 10)] : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SLOT ${index + 1}',
                style: TextStyle(color: active ? Colors.white70 : Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: active,
                onChanged: (val) {
                  setState(() {
                    _slotsActive[index] = val;
                  });
                },
                activeColor: pColor,
                activeTrackColor: pColor.withOpacity(0.25),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.black26,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!active) ...[
            const Expanded(
              child: Center(
                child: Text(
                  'INACTIVE',
                  style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            )
          ] else ...[
            // Avatar Glow Ship
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pColor.withOpacity(0.1),
                border: Border.all(color: pColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Icon(Icons.navigation, color: pColor, size: 24),
              ),
            ),
            const SizedBox(height: 12),

            // Name Input
            SizedBox(
              height: 36,
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  hintText: 'CALLSIGN',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF060A13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                controller: TextEditingController(text: _playerNames[index])
                  ..selection = TextSelection.fromPosition(TextPosition(offset: _playerNames[index].length)),
                onChanged: (val) => _playerNames[index] = val,
              ),
            ),
            const SizedBox(height: 12),

            // Input Device Selection
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<InputDeviceType>(
                  value: _inputProfiles[index].deviceType,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  onChanged: (InputDeviceType? val) {
                    if (val != null) {
                      setState(() {
                        _inputProfiles[index] = _inputProfiles[index].copyWith(deviceType: val);
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: InputDeviceType.keyboardMouse, child: Text('KEYBOARD + MOUSE')),
                    DropdownMenuItem(value: InputDeviceType.keyboardKeys, child: Text('KEYBOARD KEYS')),
                    DropdownMenuItem(value: InputDeviceType.gamepad, child: Text('GAMEPAD CONTROLLER')),
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // ==========================================
  // PANEL 2: LEADERBOARD LIST
  // ==========================================

  Widget _buildLeaderboardPanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => setState(() => _activePanel = 0),
              ),
              const Text(
                'NEON HIGH SCORE REGISTER',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  shadows: [Shadow(color: Colors.amberAccent, blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _highScores.isEmpty
                ? const Center(child: Text('NO SYSTEM DATA REGISTERED.', style: TextStyle(color: Colors.white30, fontFamily: 'monospace')))
                : ListView.builder(
                    itemCount: _highScores.length,
                    itemBuilder: (context, i) {
                      final score = _highScores[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0F1D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '#${i + 1}',
                                    style: TextStyle(
                                      color: i == 0 ? Colors.amberAccent : (i == 1 ? Colors.cyanAccent : Colors.white54),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  score.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    score.playersCount == 1 ? 'SOLO' : '${score.playersCount} CO-OP',
                                    style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${score.score} PTS',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // PANEL 3: HOW TO PLAY EXPLANATIONS
  // ==========================================

  Widget _buildHowToPlayPanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => setState(() => _activePanel = 0),
              ),
              const Text(
                'MISSION DIRECTIVES',
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DirectiveSection(
                    title: 'CORE OBJECTIVE',
                    content: 'Evade and eliminate incoming waves of hostile ships. Work together to maintain active shields. Spawning portals will surge with energy when a wave is imminent.',
                  ),
                  SizedBox(height: 18),
                  _DirectiveSection(
                    title: 'SHARED-SCREEN LOCK',
                    content: 'In co-op modes, players are tethered to the same display. The camera dynamically zooms out as you split up, but clamping barriers prevent ships from wandering off-screen.',
                  ),
                  SizedBox(height: 18),
                  _DirectiveSection(
                    title: 'CONTROLS TEMPLATE',
                    content: '• Player 1 (Mouse Mode): WASD to move. Mouse cursor to aim, click to fire. Space bar toggles automatic fire.\n'
                        '• Player 2 (Keyboard Mode): Arrow keys to navigate. Auto-shoots nearby targets. Enter toggles override.\n'
                        '• Player 3 & 4: Bound to alternate key segments (IJKL / TFGH) with auto-aim triggers.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectiveSection extends StatelessWidget {
  final String title;
  final String content;

  const _DirectiveSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
        )
      ],
    );
  }
}

class _MenuGridPainter extends CustomPainter {
  final double animationValue;

  _MenuGridPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.06 + (animationValue * 0.04))
      ..strokeWidth = 1.0;

    double spacing = 50.0;
    double offset = animationValue * spacing;

    for (double x = offset; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = offset; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Glowing scanline laser at the bottom
    final laserPaint = Paint()
      ..color = const Color(0xFF06B6D4).withOpacity(0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.8, size.width, 24), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _MenuGridPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
