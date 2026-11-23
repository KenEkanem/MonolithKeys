import 'dart:ui' show Color;

enum AppTheme { light, dark }

enum CursorPlacement { followPointer, screenCenter, windowCenter }

enum ClickAnimation { none, pulse, ripple, shrink }

/// Every user preference. Defaults live in the field initialisers, so a fresh
/// instance is the "restore defaults" state.
class Settings {
  Settings();

  static const int schemaVersion = 1;

  // General
  bool keystrokeEnabled = true;
  bool keystrokeShortcutEnabled = true;
  bool cursorEnabled = true;
  bool cursorShortcutEnabled = true;
  bool soundsEnabled = false;
  bool soundsShortcutEnabled = true;
  double soundVolume = 0.5;
  bool showWindowOnLaunch = true;
  bool startWithWindows = false;
  AppTheme theme = AppTheme.light;

  // Keystroke overlay
  String? displayId;
  double alignX = 0.5;
  double alignY = 0.92;
  String keyTemplate = 'classic';
  String keyColor = 'graphite';
  int keyScale = 100;
  bool shortcutsOnly = false;
  bool macSymbols = false;
  bool singleKeyMode = false;
  bool showMouseInput = true;
  int keyHideAfterMs = 1500;

  // Cursor highlight
  CursorPlacement cursorPlacement = CursorPlacement.followPointer;
  String cursorTemplate = 'ring';
  int cursorSize = 56;
  double cursorGlow = 0.4;
  int cursorHideAfterMs = 0;
  ClickAnimation clickAnimation = ClickAnimation.ripple;
  bool clickColorsEnabled = true;
  Color highlightColor = const Color(0x99FFC83D);
  Color leftClickColor = const Color(0xCCE5484D);
  Color rightClickColor = const Color(0xCC3B82F6);
  Color middleClickColor = const Color(0xCC22C55E);

  // Sounds
  String soundTheme = 'tactile';

  static const keyScaleRange = (min: 50, max: 200);
  static const keyHideRange = (min: 300, max: 10000);
  static const cursorSizeRange = (min: 24, max: 160);
  static const cursorHideRange = (min: 0, max: 60000);

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'keystrokeEnabled': keystrokeEnabled,
    'keystrokeShortcutEnabled': keystrokeShortcutEnabled,
    'cursorEnabled': cursorEnabled,
    'cursorShortcutEnabled': cursorShortcutEnabled,
    'soundsEnabled': soundsEnabled,
    'soundsShortcutEnabled': soundsShortcutEnabled,
    'soundVolume': soundVolume,
    'showWindowOnLaunch': showWindowOnLaunch,
    'startWithWindows': startWithWindows,
    'theme': theme.name,
    'displayId': displayId,
    'alignX': alignX,
    'alignY': alignY,
    'keyTemplate': keyTemplate,
    'keyColor': keyColor,
    'keyScale': keyScale,
    'shortcutsOnly': shortcutsOnly,
    'macSymbols': macSymbols,
    'singleKeyMode': singleKeyMode,
    'showMouseInput': showMouseInput,
    'keyHideAfterMs': keyHideAfterMs,
    'cursorPlacement': cursorPlacement.name,
    'cursorTemplate': cursorTemplate,
    'cursorSize': cursorSize,
    'cursorGlow': cursorGlow,
    'cursorHideAfterMs': cursorHideAfterMs,
    'clickAnimation': clickAnimation.name,
    'clickColorsEnabled': clickColorsEnabled,
    'highlightColor': colorToHex(highlightColor),
    'leftClickColor': colorToHex(leftClickColor),
    'rightClickColor': colorToHex(rightClickColor),
    'middleClickColor': colorToHex(middleClickColor),
    'soundTheme': soundTheme,
  };

  /// Reads a stored map leniently: missing, mistyped or out-of-range values
  /// fall back to (or are clamped towards) the defaults instead of failing.
  /// Template ids are validated by the caller, which owns the catalogues.
  factory Settings.fromJson(Map<String, Object?> json) {
    final s = Settings();
    bool b(String k, bool d) => json[k] is bool ? json[k] as bool : d;
    double d(String k, double def, double min, double max) =>
        json[k] is num ? (json[k] as num).toDouble().clamp(min, max) : def;
    int i(String k, int def, ({int min, int max}) r) =>
        json[k] is num ? (json[k] as num).round().clamp(r.min, r.max) : def;
    String str(String k, String def) => json[k] is String ? json[k] as String : def;
    T e<T extends Enum>(String k, List<T> values, T def) => values.where((v) => v.name == json[k]).firstOrNull ?? def;
    Color c(String k, Color def) => colorFromHex(json[k]) ?? def;

    s
      ..keystrokeEnabled = b('keystrokeEnabled', s.keystrokeEnabled)
      ..keystrokeShortcutEnabled = b('keystrokeShortcutEnabled', s.keystrokeShortcutEnabled)
      ..cursorEnabled = b('cursorEnabled', s.cursorEnabled)
      ..cursorShortcutEnabled = b('cursorShortcutEnabled', s.cursorShortcutEnabled)
      ..soundsEnabled = b('soundsEnabled', s.soundsEnabled)
      ..soundsShortcutEnabled = b('soundsShortcutEnabled', s.soundsShortcutEnabled)
      ..soundVolume = d('soundVolume', s.soundVolume, 0, 1)
      ..showWindowOnLaunch = b('showWindowOnLaunch', s.showWindowOnLaunch)
      ..startWithWindows = b('startWithWindows', s.startWithWindows)
      ..theme = e('theme', AppTheme.values, s.theme)
      ..displayId = json['displayId'] is String ? json['displayId'] as String : null
      ..alignX = d('alignX', s.alignX, 0, 1)
      ..alignY = d('alignY', s.alignY, 0, 1)
      ..keyTemplate = str('keyTemplate', s.keyTemplate)
      ..keyColor = str('keyColor', s.keyColor)
      ..keyScale = i('keyScale', s.keyScale, keyScaleRange)
      ..shortcutsOnly = b('shortcutsOnly', s.shortcutsOnly)
      ..macSymbols = b('macSymbols', s.macSymbols)
      ..singleKeyMode = b('singleKeyMode', s.singleKeyMode)
      ..showMouseInput = b('showMouseInput', s.showMouseInput)
      ..keyHideAfterMs = i('keyHideAfterMs', s.keyHideAfterMs, keyHideRange)
      ..cursorPlacement = e('cursorPlacement', CursorPlacement.values, s.cursorPlacement)
      ..cursorTemplate = str('cursorTemplate', s.cursorTemplate)
      ..cursorSize = i('cursorSize', s.cursorSize, cursorSizeRange)
      ..cursorGlow = d('cursorGlow', s.cursorGlow, 0, 1)
      ..cursorHideAfterMs = i('cursorHideAfterMs', s.cursorHideAfterMs, cursorHideRange)
      ..clickAnimation = e('clickAnimation', ClickAnimation.values, s.clickAnimation)
      ..clickColorsEnabled = b('clickColorsEnabled', s.clickColorsEnabled)
      ..highlightColor = c('highlightColor', s.highlightColor)
      ..leftClickColor = c('leftClickColor', s.leftClickColor)
      ..rightClickColor = c('rightClickColor', s.rightClickColor)
      ..middleClickColor = c('middleClickColor', s.middleClickColor)
      ..soundTheme = str('soundTheme', s.soundTheme);
    return s;
  }
}

/// `#AARRGGBB`, the format shown in the colour fields.
String colorToHex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Accepts `#RRGGBB` or `#AARRGGBB`, with or without the `#`.
Color? colorFromHex(Object? value) {
  if (value is! String) return null;
  final hex = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(hex)) return null;
  final argb = int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return Color(argb);
}
