import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/input_profile.dart';
import '../game/game_engine.dart';
import '../game/leaderboard.dart';
import '../game/audio_synth.dart' as synth;

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({Key? key}) : super(key: key);

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _activePanel = 0; // 0: Title, 1: Co-op Setup, 2: Leaderboard, 3: How to Play, 4: Settings
  
  // Lobby Config
  String _difficulty = 'normal';
  bool _isHardcore = false;
  String _mapType = 'grid'; // 'grid', 'pillars', 'cross'
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

  // Leaderboard filters
  String _filterPlayers = 'all';
  String _filterDifficulty = 'all';
  String _filterHardcore = 'all';

  // Settings state variables
  double _sfxVolume = 0.7;
  double _musicVolume = 0.5;
  bool _screenShake = true;
  String _colorblindFilter = 'none';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadHighScores();
    _loadSettings();
  }

  Future<void> _loadHighScores() async {
    final list = await LeaderboardManager.getHighScores();
    setState(() {
      _highScores = list;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sfxVolume = prefs.getDouble('neon_settings_sfx_volume') ?? 0.7;
      _musicVolume = prefs.getDouble('neon_settings_music_volume') ?? 0.5;
      _screenShake = prefs.getBool('neon_settings_screen_shake') ?? true;
      _colorblindFilter = prefs.getString('neon_settings_colorblind_filter') ?? 'none';

      // Load lobby configuration
      _difficulty = prefs.getString('neon_lobby_difficulty') ?? 'normal';
      _isHardcore = prefs.getBool('neon_lobby_is_hardcore') ?? false;
      _mapType = prefs.getString('neon_lobby_map_type') ?? 'grid';
      for (int i = 0; i < 4; i++) {
        _playerNames[i] = prefs.getString('neon_lobby_player_${i}_name') ?? _playerNames[i];
        _slotsActive[i] = prefs.getBool('neon_lobby_player_${i}_active') ?? (i == 0);
        final deviceName = prefs.getString('neon_lobby_player_${i}_device');
        if (deviceName != null) {
          final deviceType = InputDeviceType.values.firstWhere(
            (e) => e.name == deviceName,
            orElse: () => _inputProfiles[i].deviceType,
          );
          _inputProfiles[i] = _inputProfiles[i].copyWith(deviceType: deviceType);
        }
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('neon_settings_sfx_volume', _sfxVolume);
    await prefs.setDouble('neon_settings_music_volume', _musicVolume);
    await prefs.setBool('neon_settings_screen_shake', _screenShake);
    await prefs.setString('neon_settings_colorblind_filter', _colorblindFilter);
  }

  Future<void> _saveLobbyConfig() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < 4; i++) {
      await prefs.setString('neon_lobby_player_${i}_name', _playerNames[i]);
      await prefs.setBool('neon_lobby_player_${i}_active', _slotsActive[i]);
      await prefs.setString('neon_lobby_player_${i}_device', _inputProfiles[i].deviceType.name);
    }
    await prefs.setString('neon_lobby_difficulty', _difficulty);
    await prefs.setBool('neon_lobby_is_hardcore', _isHardcore);
    await prefs.setString('neon_lobby_map_type', _mapType);
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
          sfxVolume: _sfxVolume,
          screenShakeEnabled: _screenShake,
          colorblindFilter: _colorblindFilter,
          isHardcore: _isHardcore,
          mapType: _mapType,
          onQuit: (targetPanel) {
            Navigator.pop(context);
            _loadHighScores();
            setState(() {
              _activePanel = targetPanel; // return to requested panel
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
      case 4:
        return _buildSettingsPanel();
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
        const SizedBox(height: 40),
        _buildMenuButton('LAUNCH MISSION', 1, Colors.cyanAccent),
        const SizedBox(height: 12),
        _buildMenuButton('SETTINGS', 4, Colors.redAccent),
        const SizedBox(height: 12),
        _buildMenuButton('LEADERBOARD', 2, Colors.amberAccent),
        const SizedBox(height: 12),
        _buildMenuButton('HOW TO PLAY', 3, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildMenuButton(String text, int targetPanel, Color glowColor) {
    return SizedBox(
      width: 250,
      height: 44,
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
            fontSize: 13,
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
          const SizedBox(height: 6),

          // Map Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('MAP DESIGN:  ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
              _buildMapOption('grid', 'EMPTY GRID', const Color(0xFF38BDF8)),
              _buildMapOption('pillars', 'PILLARS', const Color(0xFFF59E0B)),
              _buildMapOption('cross', 'CROSS WALLS', const Color(0xFFEC4899)),
            ],
          ),
          const SizedBox(height: 6),

          // Hardcore Mode Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('HARDCORE MODE:  ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
              Switch(
                value: _isHardcore,
                onChanged: (val) {
                  setState(() {
                    _isHardcore = val;
                  });
                  _saveLobbyConfig();
                },
                activeColor: const Color(0xFFEF4444),
                activeTrackColor: const Color(0xFFEF4444).withOpacity(0.25),
              ),
              const SizedBox(width: 6),
              Text(
                _isHardcore ? 'ON (ONE-HIT DEATH, NO INVULN)' : 'OFF',
                style: TextStyle(
                  color: _isHardcore ? const Color(0xFFEF4444) : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Player Slots Configuration (cards expanded slightly to prevent overlaps)
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
          if (val) {
            setState(() => _difficulty = diff);
            _saveLobbyConfig();
          }
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

  Widget _buildMapOption(String mapType, String displayName, Color activeColor) {
    bool isSelected = _mapType == mapType;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(displayName, style: const TextStyle(fontSize: 10)),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() => _mapType = mapType);
            _saveLobbyConfig();
          }
        },
        selectedColor: activeColor.withOpacity(0.35),
        backgroundColor: const Color(0xFF0C1324),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontWeight: FontWeight.bold,
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
      width: 162, // Card width increased from 155 to 162 to avoid horizontal dropdown overflows
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
                  _saveLobbyConfig();
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
                onChanged: (val) {
                  _playerNames[index] = val;
                  _saveLobbyConfig();
                },
              ),
            ),
            const SizedBox(height: 12),

            // Input Device Selection (text tags shortened to prevent card overlaps)
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<InputDeviceType>(
                  value: _inputProfiles[index].deviceType,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  onChanged: (InputDeviceType? val) {
                    if (val != null) {
                      setState(() {
                        _inputProfiles[index] = _inputProfiles[index].copyWith(deviceType: val);
                      });
                      _saveLobbyConfig();
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: InputDeviceType.keyboardMouse, child: Text('KBD + MOUSE')),
                    DropdownMenuItem(value: InputDeviceType.keyboardKeys, child: Text('KBD KEYS')),
                    DropdownMenuItem(value: InputDeviceType.gamepad, child: Text('GAMEPAD')),
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
  // PANEL 4: PERSISTED SETTINGS PANEL
  // ==========================================

  Widget _buildSettingsPanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () {
                  _saveSettings();
                  setState(() => _activePanel = 0);
                },
              ),
              const Text(
                'SYSTEM SETTINGS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                // SFX Volume Slider
                _buildSliderSetting(
                  label: 'SOUND FX VOLUME',
                  value: _sfxVolume,
                  onChanged: (val) {
                    setState(() {
                      _sfxVolume = val;
                    });
                    // Play test beep on slide adjust
                    synth.playSfx('playLaser', _sfxVolume);
                  },
                ),
                const SizedBox(height: 18),

                // Music Volume Slider
                _buildSliderSetting(
                  label: 'MUSIC VOLUME (NOT USED)',
                  value: _musicVolume,
                  onChanged: (val) {
                    setState(() {
                      _musicVolume = val;
                    });
                  },
                ),
                const SizedBox(height: 18),

                // Screen Shake Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F1D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SCREEN SHAKE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Switch(
                        value: _screenShake,
                        onChanged: (val) {
                          setState(() {
                            _screenShake = val;
                          });
                        },
                        activeColor: const Color(0xFF06B6D4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Color-blind filter dropdown selection (fully clickable)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F1D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _colorblindFilter,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: const Color(0xFF0F172A),
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: Icon(Icons.arrow_drop_down, color: Color(0xFF06B6D4)),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        final itemsMap = {
                          'none': 'NONE',
                          'protanopia': 'PROTANOPIA (RED-BLIND)',
                          'deuteranopia': 'DEUTERANOPIA (GREEN-BLIND)',
                          'tritanopia': 'TRITANOPIA (BLUE-BLIND)',
                        };
                        return itemsMap.entries.map<Widget>((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'COLOR-BLIND FILTER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  e.value,
                                  style: const TextStyle(
                                    color: Color(0xFF06B6D4),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('NONE')),
                        DropdownMenuItem(value: 'protanopia', child: Text('PROTANOPIA (RED-BLIND)')),
                        DropdownMenuItem(value: 'deuteranopia', child: Text('DEUTERANOPIA (GREEN-BLIND)')),
                        DropdownMenuItem(value: 'tritanopia', child: Text('TRITANOPIA (BLUE-BLIND)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _colorblindFilter = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                _saveSettings();
                setState(() => _activePanel = 0);
              },
              child: const Text('SAVE & CLOSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF06B6D4),
              inactiveTrackColor: const Color(0xFF1E293B),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF06B6D4).withOpacity(0.12),
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
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
          const SizedBox(height: 10),
          // Dropdown filters row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFilterDropdown('PLAYERS', _filterPlayers, {
                'all': 'ALL',
                '1': 'SOLO',
                'coop': 'CO-OP',
              }, (val) {
                setState(() => _filterPlayers = val);
              }),
              _buildFilterDropdown('DIFFICULTY', _filterDifficulty, {
                'all': 'ALL',
                'easy': 'EASY',
                'normal': 'NORMAL',
                'hard': 'HARD',
              }, (val) {
                setState(() => _filterDifficulty = val);
              }),
              _buildFilterDropdown('MODE', _filterHardcore, {
                'all': 'ALL',
                'standard': 'STANDARD',
                'hardcore': 'HARDCORE',
              }, (val) {
                setState(() => _filterHardcore = val);
              }),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: () {
              final filteredScores = _highScores.where((score) {
                if (_filterPlayers == '1' && score.playersCount != 1) return false;
                if (_filterPlayers == 'coop' && score.playersCount <= 1) return false;
                if (_filterDifficulty != 'all' && score.difficulty != _filterDifficulty) return false;
                if (_filterHardcore == 'standard' && score.isHardcore) return false;
                if (_filterHardcore == 'hardcore' && !score.isHardcore) return false;
                return true;
              }).toList();

              if (filteredScores.isEmpty) {
                return const Center(child: Text('NO DATA MATCHES FILTERS.', style: TextStyle(color: Colors.white30, fontFamily: 'monospace')));
              }

              return ListView.builder(
                itemCount: filteredScores.length,
                itemBuilder: (context, i) {
                  final score = filteredScores[i];
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
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: score.difficulty.toLowerCase() == 'easy'
                                    ? const Color(0xFF10B981).withOpacity(0.15)
                                    : (score.difficulty.toLowerCase() == 'hard'
                                        ? const Color(0xFFEF4444).withOpacity(0.15)
                                        : const Color(0xFF06B6D4).withOpacity(0.15)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: score.difficulty.toLowerCase() == 'easy'
                                      ? const Color(0xFF10B981)
                                      : (score.difficulty.toLowerCase() == 'hard'
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF06B6D4)),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                score.difficulty.toUpperCase(),
                                style: TextStyle(
                                  color: score.difficulty.toLowerCase() == 'easy'
                                      ? const Color(0xFF10B981)
                                      : (score.difficulty.toLowerCase() == 'hard'
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF06B6D4)),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (score.isHardcore) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFEF4444), width: 1),
                                ),
                                child: const Text(
                                  'HARDCORE',
                                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
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
              );
            }(),
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

  Widget _buildFilterDropdown(
    String label,
    String currentValue,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1324),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isDense: true,
          dropdownColor: const Color(0xFF0A0F1D),
          icon: const Padding(
            padding: EdgeInsets.only(right: 8.0, left: 4.0),
            child: Icon(Icons.arrow_drop_down, color: Colors.cyanAccent, size: 16),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
          selectedItemBuilder: (BuildContext context) {
            return options.entries.map<Widget>((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    children: [
                      TextSpan(
                        text: '$label: ',
                        style: const TextStyle(color: Colors.white30),
                      ),
                      TextSpan(
                        text: e.value,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
          items: options.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key,
              child: Text(e.value),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
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
