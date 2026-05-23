import 'package:flutter/services.dart';

enum InputDeviceType {
  keyboardMouse, // WASD + Mouse aim / click
  keyboardKeys,  // Custom keys for movement + shooting button
  gamepad,       // Gamepad controller
}

class InputProfile {
  final InputDeviceType deviceType;
  final int gamepadIndex; // index 0-3 for gamepads
  
  // Keyboard keys mapping
  final LogicalKeyboardKey moveUp;
  final LogicalKeyboardKey moveDown;
  final LogicalKeyboardKey moveLeft;
  final LogicalKeyboardKey moveRight;
  final LogicalKeyboardKey actionShoot;

  const InputProfile({
    required this.deviceType,
    this.gamepadIndex = 0,
    this.moveUp = LogicalKeyboardKey.keyW,
    this.moveDown = LogicalKeyboardKey.keyS,
    this.moveLeft = LogicalKeyboardKey.keyA,
    this.moveRight = LogicalKeyboardKey.keyD,
    this.actionShoot = LogicalKeyboardKey.space,
  });

  // Default templates
  static const InputProfile player1Default = InputProfile(
    deviceType: InputDeviceType.keyboardMouse,
    moveUp: LogicalKeyboardKey.keyW,
    moveDown: LogicalKeyboardKey.keyS,
    moveLeft: LogicalKeyboardKey.keyA,
    moveRight: LogicalKeyboardKey.keyD,
  );

  static const InputProfile player2Default = InputProfile(
    deviceType: InputDeviceType.keyboardKeys,
    moveUp: LogicalKeyboardKey.arrowUp,
    moveDown: LogicalKeyboardKey.arrowDown,
    moveLeft: LogicalKeyboardKey.arrowLeft,
    moveRight: LogicalKeyboardKey.arrowRight,
    actionShoot: LogicalKeyboardKey.enter,
  );

  static const InputProfile player3Default = InputProfile(
    deviceType: InputDeviceType.keyboardKeys,
    moveUp: LogicalKeyboardKey.keyI,
    moveDown: LogicalKeyboardKey.keyK,
    moveLeft: LogicalKeyboardKey.keyJ,
    moveRight: LogicalKeyboardKey.keyL,
    actionShoot: LogicalKeyboardKey.keyO,
  );

  static const InputProfile player4Default = InputProfile(
    deviceType: InputDeviceType.keyboardKeys,
    moveUp: LogicalKeyboardKey.keyT,
    moveDown: LogicalKeyboardKey.keyG,
    moveLeft: LogicalKeyboardKey.keyF,
    moveRight: LogicalKeyboardKey.keyH,
    actionShoot: LogicalKeyboardKey.keyY,
  );

  InputProfile copyWith({
    InputDeviceType? deviceType,
    int? gamepadIndex,
    LogicalKeyboardKey? moveUp,
    LogicalKeyboardKey? moveDown,
    LogicalKeyboardKey? moveLeft,
    LogicalKeyboardKey? moveRight,
    LogicalKeyboardKey? actionShoot,
  }) {
    return InputProfile(
      deviceType: deviceType ?? this.deviceType,
      gamepadIndex: gamepadIndex ?? this.gamepadIndex,
      moveUp: moveUp ?? this.moveUp,
      moveDown: moveDown ?? this.moveDown,
      moveLeft: moveLeft ?? this.moveLeft,
      moveRight: moveRight ?? this.moveRight,
      actionShoot: actionShoot ?? this.actionShoot,
    );
  }
}
