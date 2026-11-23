// End-to-end checks against the real Windows layer. Runs inside the built
// app on Windows:
//
//   flutter test integration_test -d windows
//
// Keys are injected through the OS with keybd_event, so they travel through
// the low-level hook and RegisterHotKey exactly like physical key presses.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:monolithkeys/app_controller.dart';
import 'package:monolithkeys/keystroke/keys.dart';
import 'package:monolithkeys/license/license.dart';
import 'package:monolithkeys/native/native_host.dart';
import 'package:monolithkeys/settings/settings_store.dart';
import 'package:monolithkeys/sound/sound_synth.dart';
import 'package:monolithkeys/ui/app.dart';

typedef _KeybdEventC = Void Function(Uint8 vk, Uint8 scan, Uint32 flags, IntPtr extra);
typedef _KeybdEvent = void Function(int vk, int scan, int flags, int extra);

final _keybdEvent = DynamicLibrary.open('user32.dll').lookupFunction<_KeybdEventC, _KeybdEvent>('keybd_event');
const _keyUp = 0x0002;
const _f13 = 0x7C; // No default action in Windows, so safe to inject.

void press(List<int> vks) {
  for (final vk in vks) {
    _keybdEvent(vk, 0, 0, 0);
  }
  for (final vk in vks.reversed) {
    _keybdEvent(vk, 0, _keyUp, 0);
  }
}

Future<bool> waitFor(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return true;
  }
  return false;
}

Future<bool> startupEntryExists() async {
  final r = await Process.run('reg', [
    'query',
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
    '/v',
    'MonolithKeys',
  ]);
  return r.exitCode == 0;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppController controller;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('monolithkeys_it');
    controller = AppController(
      settings: SettingsController(SettingsStore(File('${dir.path}\\settings.json'))),
      native: MethodChannelNativeHost(),
      license: LicenseService(File('${dir.path}\\license.json'), const UnconfiguredLicenseClient()),
    );
  });

  testWidgets('starts and registers its shortcuts', (tester) async {
    await tester.pumpWidget(MonolithKeysApp(controller: controller));
    // Shown so the engine keeps producing frames for the test binding.
    await controller.start(background: false);
    await tester.pumpAndSettle();
    for (final f in Feature.values) {
      expect(controller.hotkeys.value[f], isNot(HotkeyStatus.off), reason: '$f shortcut is attempted');
    }
  });

  testWidgets('lists connected displays', (tester) async {
    final displays = await controller.native.displays();
    expect(displays, isNotEmpty);
    expect(displays.where((d) => d.primary), hasLength(1));
    for (final d in displays) {
      expect(d.bounds.width, greaterThan(0));
      expect(d.scale, greaterThanOrEqualTo(1));
      expect(d.bounds.contains(d.workArea.center), isTrue);
    }
  });

  testWidgets('real key presses reach the overlay through the hook', (tester) async {
    press([_f13]);
    expect(await waitFor(tester, () => controller.composer.strokes.any((s) => s.toString() == 'F13')), isTrue);
    press([Vk.lControl, _f13]);
    expect(await waitFor(tester, () => controller.composer.strokes.any((s) => s.toString() == 'Ctrl + F13')), isTrue);
  });

  testWidgets('the global shortcut toggles the keystroke overlay', (tester) async {
    if (controller.hotkeys.value[Feature.keystroke] != HotkeyStatus.registered) {
      markTestSkipped('Ctrl+Alt+Shift+K is taken by another app on this machine');
      return;
    }
    expect(controller.settings.value.keystrokeEnabled, isTrue);
    press([Vk.lControl, Vk.lMenu, Vk.lShift, 0x4B]);
    expect(await waitFor(tester, () => !controller.settings.value.keystrokeEnabled), isTrue);
    press([Vk.lControl, Vk.lMenu, Vk.lShift, 0x4B]);
    expect(await waitFor(tester, () => controller.settings.value.keystrokeEnabled), isTrue);
  });

  testWidgets('keys are ignored while the overlay is off', (tester) async {
    controller.settings.update((s) => s.keystrokeEnabled = false);
    await tester.pump(const Duration(milliseconds: 300));
    press([_f13]);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.composer.strokes, isEmpty);
    controller.settings.update((s) => s.keystrokeEnabled = true);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('start with Windows adds and removes the startup entry', (tester) async {
    controller.settings.update((s) => s.startWithWindows = true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await startupEntryExists(), isTrue);
    controller.settings.update((s) => s.startWithWindows = false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await startupEntryExists(), isFalse);
  });

  testWidgets('every template, cursor style and sound theme applies without errors', (tester) async {
    for (final theme in soundThemes) {
      await controller.previewSound(theme.id);
    }
    for (final template in ['classic', 'minimal', 'soft', 'accent', 'presentation']) {
      controller.settings.update(
        (s) => s
          ..keyTemplate = template
          ..macSymbols = !s.macSymbols,
      );
      press([Vk.lShift, _f13]);
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (final shape in ['ring', 'halo', 'dashed-disc', 'solid-diamond', 'target', 'dot']) {
      controller.settings.update(
        (s) => s
          ..cursorTemplate = shape
          ..cursorGlow = 1,
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    controller.settings.update((s) => s.displayId = r'\\.\DISPLAY_THAT_DOES_NOT_EXIST');
    press([_f13]);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings persist to disk', (tester) async {
    controller.settings.update((s) => s.keyScale = 135);
    await controller.settings.flush();
    expect(SettingsStore(File('${dir.path}\\settings.json')).load().keyScale, 135);
  });
}
