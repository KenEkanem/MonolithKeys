import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cursor/cursor_templates.dart';
import 'keystroke/composer.dart';
import 'keystroke/key_templates.dart';
import 'license/license.dart';
import 'log.dart';
import 'native/native_host.dart';
import 'settings/settings.dart';
import 'settings/settings_store.dart';
import 'sound/sound_synth.dart';

/// Distance between the keystroke overlay and the display edge, in logical px.
const overlayMargin = 24.0;

/// The configuration the Windows layer applies, derived from [Settings].
Map<String, Object?> nativeConfig(Settings s) {
  final template = cursorTemplateById(s.cursorTemplate);
  return {
    'keyEvents': s.keystrokeEnabled,
    'mouseEvents': s.keystrokeEnabled && s.showMouseInput,
    'sounds': s.soundsEnabled,
    'volume': s.soundVolume,
    // Virtual-key code of each shortcut's letter (always with Ctrl + Alt + Shift), 0 when off.
    'hotkeys': {
      for (final (feature, enabled) in [
        (Feature.keystroke, s.keystrokeShortcutEnabled),
        (Feature.cursor, s.cursorShortcutEnabled),
        (Feature.sounds, s.soundsShortcutEnabled),
      ])
        feature.name: enabled ? shortcutLetters[feature]!.codeUnitAt(0) : 0,
    },
    'tray': {
      Feature.keystroke.name: s.keystrokeEnabled,
      Feature.cursor.name: s.cursorEnabled,
      Feature.sounds.name: s.soundsEnabled,
    },
    'cursor': {
      'enabled': s.cursorEnabled,
      'placement': s.cursorPlacement.index,
      ...template.toNative(),
      'size': s.cursorSize.toDouble(),
      'glow': s.cursorGlow,
      'hideAfterMs': s.cursorHideAfterMs,
      'animation': s.clickAnimation.index,
      'clickColors': s.clickColorsEnabled,
      'color': s.highlightColor.toARGB32(),
      'left': s.leftClickColor.toARGB32(),
      'right': s.rightClickColor.toARGB32(),
      'middle': s.middleClickColor.toARGB32(),
    },
    'overlay': {'displayId': s.displayId ?? '', 'alignX': s.alignX, 'alignY': s.alignY, 'margin': overlayMargin},
    'startup': s.startWithWindows,
    'dark': s.theme == AppTheme.dark,
  };
}

/// Connects settings, the native layer and the keystroke composer.
class AppController {
  AppController({required this.settings, required this.native, required this.license, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final SettingsController settings;
  final NativeHost native;
  final LicenseService license;
  final DateTime Function() _now;

  final composer = KeystrokeComposer();
  final hotkeys = ValueNotifier<Map<Feature, HotkeyStatus>>({});

  /// Bumped when monitors are connected, removed or rearranged.
  final displaysRevision = ValueNotifier<int>(0);

  StreamSubscription<NativeEvent>? _events;
  Timer? _hideTimer;
  String? _appliedConfig;
  String? _loadedSoundTheme;

  Future<void> start({required bool background}) async {
    _events = native.events.listen(_onEvent);
    settings.addListener(_apply);
    await _apply();
    if (settings.value.showWindowOnLaunch && !background) await native.showWindow();
    Log.info('Started${background ? ' in background' : ''}');
  }

  Future<void> exit() async {
    Log.info('Exiting');
    _hideTimer?.cancel();
    settings.removeListener(_apply);
    await _events?.cancel();
    await settings.flush();
    await native.quit();
  }

  void toggle(Feature feature) => settings.update(
    (s) => switch (feature) {
      Feature.keystroke => s.keystrokeEnabled = !s.keystrokeEnabled,
      Feature.cursor => s.cursorEnabled = !s.cursorEnabled,
      Feature.sounds => s.soundsEnabled = !s.soundsEnabled,
    },
  );

  /// Plays a sample of [theme], loading its sounds first when needed.
  Future<void> previewSound(String theme) async {
    await _loadSounds(theme);
    await native.playSound();
  }

  Future<void> _loadSounds(String theme) async {
    if (_loadedSoundTheme == theme) return;
    _loadedSoundTheme = theme;
    await native.setSoundBank(soundBank(theme));
  }

  Future<void> _apply() async {
    final s = settings.value;
    composer.options = ComposerOptions(
      shortcutsOnly: s.shortcutsOnly,
      singleKeyMode: s.singleKeyMode,
      macSymbols: s.macSymbols,
      showMouse: s.showMouseInput,
      hideAfter: Duration(milliseconds: s.keyHideAfterMs),
    );
    try {
      if (s.soundsEnabled) await _loadSounds(s.soundTheme);
      final config = nativeConfig(s);
      final encoded = jsonEncode(config);
      if (encoded != _appliedConfig) {
        _appliedConfig = encoded;
        hotkeys.value = await native.configure(config);
        if (hotkeys.value.containsValue(HotkeyStatus.conflict)) {
          Log.info('Some shortcuts are already registered by another app: ${hotkeys.value}');
        }
      }
      if (!s.keystrokeEnabled) {
        composer.reset();
        await native.hideKeystrokes();
      } else if (composer.strokes.isNotEmpty) {
        await _render();
      }
    } on Object catch (e, st) {
      Log.error('Applying settings to the native layer failed', e, st);
    }
  }

  void _onEvent(NativeEvent event) {
    final s = settings.value;
    switch (event) {
      case KeyInput(:final vk, :final down, :final char, :final modifiers):
        if (!s.keystrokeEnabled) return;
        final changed = down
            ? composer.keyDown(vk, char: char, heldModifiers: modifiers, at: _now())
            : composer.keyUp(vk, at: _now());
        _afterInput(changed);
      case MouseInput(:final action, :final modifiers):
        if (!s.keystrokeEnabled) return;
        _afterInput(composer.mouse(action, heldModifiers: modifiers, at: _now()));
      case ToggleRequested(:final feature):
        toggle(feature);
      case ExitRequested():
        exit();
      case DisplaysChanged():
        displaysRevision.value++;
    }
  }

  void _afterInput(bool changed) {
    if (changed) _render();
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    final deadline = composer.hideDeadline;
    if (deadline == null) return;
    final wait = deadline.difference(_now());
    _hideTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (composer.tick(_now())) {
        native.hideKeystrokes();
      } else {
        // A key is still held; check again once the hide delay passes.
        _hideTimer = Timer(composer.options.hideAfter, _scheduleHide);
      }
    });
  }

  Future<void> _render() {
    final s = settings.value;
    return native.showKeystrokes(
      overlayScene(composer.strokes, keyTemplateById(s.keyTemplate), keyColorById(s.keyColor), s.keyScale / 100),
    );
  }
}
