import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../cursor/cursor_templates.dart';
import '../keystroke/key_templates.dart';
import '../log.dart';
import '../sound/sound_synth.dart';
import 'settings.dart';

/// Loads and saves [Settings] as JSON. Writes go to a temporary file first and
/// are then renamed over the real one, so a crash mid-write never leaves a
/// truncated settings file behind.
class SettingsStore {
  SettingsStore(this.file);

  final File file;

  Settings load() {
    if (!file.existsSync()) return Settings();
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, Object?>) throw const FormatException('Not an object');
      return _validated(Settings.fromJson(json));
    } on Object catch (e) {
      final backup = File('${file.path}.corrupt');
      Log.error('Settings file unreadable, keeping a copy at ${backup.path} and using defaults', e);
      try {
        file.renameSync(backup.path);
      } on FileSystemException catch (e) {
        Log.error('Could not set the unreadable settings file aside', e);
      }
      return Settings();
    }
  }

  Future<void> save(Settings settings) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(const JsonEncoder.withIndent('  ').convert(settings.toJson()), flush: true);
    await temp.rename(file.path);
  }

  static Settings _validated(Settings s) {
    final defaults = Settings();
    if (!keyTemplates.any((t) => t.id == s.keyTemplate)) s.keyTemplate = defaults.keyTemplate;
    if (!keyColors.any((c) => c.id == s.keyColor)) s.keyColor = defaults.keyColor;
    if (!cursorTemplates.any((t) => t.id == s.cursorTemplate)) s.cursorTemplate = defaults.cursorTemplate;
    if (!soundThemes.any((t) => t.id == s.soundTheme)) s.soundTheme = defaults.soundTheme;
    return s;
  }
}

/// Holds the live settings, notifies listeners on every change and saves them
/// shortly afterwards, so dragging a slider does not hit the disk per frame.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store, {this.saveDelay = const Duration(milliseconds: 400)}) : _value = _store.load();

  final SettingsStore _store;
  final Duration saveDelay;
  Settings _value;
  Timer? _saveTimer;

  Settings get value => _value;

  void update(void Function(Settings s) change) {
    change(_value);
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, flush);
  }

  void restoreDefaults() => update((_) => _value = Settings());

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      await _store.save(_value);
    } on FileSystemException catch (e) {
      Log.error('Saving settings failed', e);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
