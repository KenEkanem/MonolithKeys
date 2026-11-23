import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:monolithkeys/settings/settings.dart';
import 'package:monolithkeys/settings/settings_store.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mk_settings');
    file = File('${dir.path}/settings.json');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a missing file gives defaults', () {
    final s = SettingsStore(file).load();
    expect(s.toJson(), Settings().toJson());
  });

  test('every field survives a save and load', () async {
    final s = Settings()
      ..keystrokeEnabled = false
      ..soundsEnabled = true
      ..soundVolume = 0.25
      ..theme = AppTheme.dark
      ..displayId = r'\\.\DISPLAY2'
      ..alignX = 0.1
      ..alignY = 0.2
      ..keyTemplate = 'soft'
      ..keyColor = 'teal'
      ..keyScale = 140
      ..shortcutsOnly = true
      ..macSymbols = true
      ..singleKeyMode = true
      ..showMouseInput = false
      ..keyHideAfterMs = 2500
      ..cursorPlacement = CursorPlacement.windowCenter
      ..cursorTemplate = 'target'
      ..cursorSize = 90
      ..cursorGlow = 0.8
      ..cursorHideAfterMs = 3000
      ..clickAnimation = ClickAnimation.shrink
      ..clickColorsEnabled = false
      ..highlightColor = const Color(0x8011AA22)
      ..soundTheme = 'typewriter'
      ..startWithWindows = true
      ..showWindowOnLaunch = false;
    await SettingsStore(file).save(s);
    expect(SettingsStore(file).load().toJson(), s.toJson());
    expect(File('${file.path}.tmp').existsSync(), isFalse, reason: 'temporary file is renamed into place');
  });

  test('out-of-range and mistyped values are clamped or defaulted', () {
    file.writeAsStringSync(
      jsonEncode({
        'soundVolume': 7,
        'alignX': -3,
        'keyScale': 9000,
        'cursorSize': 'big',
        'theme': 'purple',
        'keystrokeEnabled': 'yes',
        'highlightColor': 'not a colour',
      }),
    );
    final s = SettingsStore(file).load();
    final d = Settings();
    expect(s.soundVolume, 1);
    expect(s.alignX, 0);
    expect(s.keyScale, Settings.keyScaleRange.max);
    expect(s.cursorSize, d.cursorSize);
    expect(s.theme, d.theme);
    expect(s.keystrokeEnabled, d.keystrokeEnabled);
    expect(s.highlightColor, d.highlightColor);
  });

  test('unknown template, colour and sound ids fall back to defaults', () {
    file.writeAsStringSync(
      jsonEncode({'keyTemplate': 'gone', 'keyColor': 'gone', 'cursorTemplate': 'gone', 'soundTheme': 'gone'}),
    );
    final s = SettingsStore(file).load();
    final d = Settings();
    expect(
      [s.keyTemplate, s.keyColor, s.cursorTemplate, s.soundTheme],
      [d.keyTemplate, d.keyColor, d.cursorTemplate, d.soundTheme],
    );
  });

  test('a corrupt file is set aside and defaults are used', () {
    file.writeAsStringSync('{ this is not json');
    final s = SettingsStore(file).load();
    expect(s.toJson(), Settings().toJson());
    expect(File('${file.path}.corrupt').readAsStringSync(), '{ this is not json');
    expect(file.existsSync(), isFalse);
  });

  test('controller saves after changes and restores defaults', () async {
    final controller = SettingsController(SettingsStore(file), saveDelay: Duration.zero);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.update((s) => s.keyScale = 150);
    await controller.flush();
    expect(SettingsStore(file).load().keyScale, 150);

    controller.restoreDefaults();
    await controller.flush();
    expect(controller.value.keyScale, Settings().keyScale);
    expect(SettingsStore(file).load().keyScale, Settings().keyScale);
    expect(notified, 2);
  });

  test('hex colours parse with and without alpha', () {
    expect(colorFromHex('#FF0000'), const Color(0xFFFF0000));
    expect(colorFromHex('80ff0000'), const Color(0x80FF0000));
    expect(colorFromHex('#F00'), isNull);
    expect(colorToHex(const Color(0x0A0B0C0D)), '#0A0B0C0D');
  });
}
