# Neon Survival

A sleek, retro cyberpunk cyberpunk-themed vector arcade survival shooter built in Flutter. 

Survival isn't just a mission, it's a neon-flooded retro arcade battle. Drive your ship, pick up weapon upgrades, navigate hazardous map obstacles, and climb the local high score register!

---

## ⚠️ Co-Op Multiplayer Status
> [!WARNING]
> **Local Co-Op Multiplayer** (supporting up to 4 players on a single screen) is fully implemented in this codebase, but it is currently **untested**. Please expect experimental behavior if playing with multiple controllers/keyboards simultaneously. Reports of bugs or gameplay imbalances are welcome!

---

## 🎮 Core Features

* **High-Octane Arcade Action**: Pulsing cyberpunk vectors, screen shake, neon particle explosions, and retro SFX synthesized directly using browser/native oscillators.
* **Specialized Weapon Arsenal**:
  * **Default Blaster**: Infinite ammo, balanced firing rate.
  * **Spread Shot**: Fires a 3-bullet fan to clear out crowded paths.
  * **Laser Beam**: Extremely fast piercing lasers that penetrate enemies.
  * **Plasma Launcher**: Heavy, slow-moving projectiles that cause radial splash damage.
* **Neon Pickups**: Weapon ammo packs, health restoration, and extra life items dynamically drop from defeated enemies or spawn randomly.
* **Map obstacle sliding**: Play on *Empty Grid*, *Pillars*, or *Cross Walls*. Entities slide smoothly along walls, and projectiles detonate instantly on impact.
* **Local Leaderboard**: Fully filterable high scores register with real-time dropdowns (by player count, difficulty, and hardcore mode).

---

## 🛠️ Standalone Run Instructions

To run the standalone game locally in debug mode, make sure you have the [Flutter SDK](https://flutter.dev) installed, then execute:

```bash
.\run_standalone.bat
```

Or run via the Flutter CLI:
```bash
flutter run -d chrome
```

---

## 📦 Cross-Platform Compilation (Windows & Linux Executables)

This codebase supports compiling into native desktop applications for Windows and Linux.

### Enable Desktop Platforms
```bash
flutter config --enable-windows-desktop --enable-linux-desktop
```

### Windows Compilation (on a Windows machine)
```bash
flutter build windows
```
*Outputs a native standalone `.exe` bundle under `build/windows/x64/runner/Release/`.*

### Linux Compilation (on a Linux machine)
```bash
flutter build linux
```
*Outputs a native binary bundle under `build/linux/x64/release/bundle/`.*

### Web Compilation
```bash
flutter build web --release --no-wasm-dry-run
```
*Outputs web assets under `build/web/`.*
