import 'dart:async';

import 'package:flutter/services.dart';

import '../display/display_layout.dart';
import '../log.dart';
import '../keystroke/keys.dart';

/// Messages the Windows layer sends to Dart.
sealed class NativeEvent {
  const NativeEvent();
}

class KeyInput extends NativeEvent {
  const KeyInput(this.vk, {required this.down, this.char, required this.modifiers});

  final int vk;
  final bool down;
  final String? char;
  final Set<Modifier> modifiers;
}

class MouseInput extends NativeEvent {
  const MouseInput(this.action, {required this.modifiers});

  final MouseAction action;
  final Set<Modifier> modifiers;
}

enum Feature { keystroke, cursor, sounds }

/// The global shortcut letter for each feature. The modifiers are always
/// Ctrl + Alt + Shift; the native layer registers whatever is listed here.
const shortcutLetters = {Feature.keystroke: 'K', Feature.cursor: 'N', Feature.sounds: 'M'};

/// A global shortcut fired, or its tray menu item was clicked.
class ToggleRequested extends NativeEvent {
  const ToggleRequested(this.feature);

  final Feature feature;
}

class ExitRequested extends NativeEvent {
  const ExitRequested();
}

class DisplaysChanged extends NativeEvent {
  const DisplaysChanged();
}

enum HotkeyStatus { off, registered, conflict }

/// The Windows side of the app: hooks, shortcuts, tray, overlays and audio.
abstract interface class NativeHost {
  Stream<NativeEvent> get events;

  /// Applies the full native configuration and reports shortcut registration.
  Future<Map<Feature, HotkeyStatus>> configure(Map<String, Object?> config);

  Future<void> setSoundBank(List<List<Uint8List>> bank);

  /// Plays one key sound from the loaded bank, even when sounds are off.
  Future<void> playSound();

  Future<void> showKeystrokes(Map<String, Object?> scene);

  Future<void> hideKeystrokes();

  Future<List<DisplayInfo>> displays();

  Future<String?> wallpaperPath();

  Future<void> showWindow();

  Future<void> hideWindow();

  Future<void> startWindowDrag();

  Future<void> open(String target);

  Future<void> quit();
}

Set<Modifier> _modifiers(Object? mask) {
  final m = mask is int ? mask : 0;
  return {
    for (final mod in Modifier.values)
      if (m & (1 << mod.index) != 0) mod,
  };
}

class MethodChannelNativeHost implements NativeHost {
  MethodChannelNativeHost() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('monolithkeys/native');
  final _events = StreamController<NativeEvent>.broadcast();

  @override
  Stream<NativeEvent> get events => _events.stream;

  Future<Object?> _onCall(MethodCall call) async {
    final args = call.arguments is Map ? call.arguments as Map : const {};
    if (call.method == 'log') {
      Log.info('Native: ${args['message']}');
      return null;
    }
    final event = switch (call.method) {
      'key' => KeyInput(
        args['vk'] as int,
        down: args['down'] as bool,
        char: args['char'] as String?,
        modifiers: _modifiers(args['mods']),
      ),
      'mouse' => MouseInput(MouseAction.values[args['action'] as int], modifiers: _modifiers(args['mods'])),
      'toggle' => ToggleRequested(Feature.values.byName(args['feature'] as String)),
      'exit' => const ExitRequested(),
      'displaysChanged' => const DisplaysChanged(),
      _ => null,
    };
    if (event != null) _events.add(event);
    return null;
  }

  @override
  Future<Map<Feature, HotkeyStatus>> configure(Map<String, Object?> config) async {
    final result = await _channel.invokeMapMethod<String, String>('configure', config) ?? const {};
    return {for (final f in Feature.values) f: HotkeyStatus.values.asNameMap()[result[f.name]] ?? HotkeyStatus.off};
  }

  @override
  Future<void> setSoundBank(List<List<Uint8List>> bank) => _channel.invokeMethod('setSoundBank', bank);

  @override
  Future<void> playSound() => _channel.invokeMethod('playSound');

  @override
  Future<void> showKeystrokes(Map<String, Object?> scene) => _channel.invokeMethod('showKeystrokes', scene);

  @override
  Future<void> hideKeystrokes() => _channel.invokeMethod('hideKeystrokes');

  @override
  Future<List<DisplayInfo>> displays() async {
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>('displays') ?? const [];
    return list.map(DisplayInfo.fromNative).toList();
  }

  @override
  Future<String?> wallpaperPath() => _channel.invokeMethod<String>('wallpaper');

  @override
  Future<void> showWindow() => _channel.invokeMethod('showWindow');

  @override
  Future<void> hideWindow() => _channel.invokeMethod('hideWindow');

  @override
  Future<void> startWindowDrag() => _channel.invokeMethod('startWindowDrag');

  @override
  Future<void> open(String target) => _channel.invokeMethod('open', {'target': target});

  @override
  Future<void> quit() => _channel.invokeMethod('quit');
}
