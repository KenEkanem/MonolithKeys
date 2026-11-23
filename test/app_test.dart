import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:monolithkeys/app_controller.dart';
import 'package:monolithkeys/keystroke/keys.dart';
import 'package:monolithkeys/native/native_host.dart';
import 'package:monolithkeys/settings/settings.dart';
import 'package:monolithkeys/ui/app.dart';
import 'package:monolithkeys/ui/theme.dart';

import 'fakes.dart';

void main() {
  group('controller', () {
    var now = DateTime(2026);

    /// Lets the debounced settings save and any overlay hide timer run.
    Future<void> settle(WidgetTester tester) => tester.pump(const Duration(seconds: 15));

    testWidgets('startup applies configuration and shows the window', (tester) async {
      final t = testController();
      await t.controller.start(background: false);
      expect(t.native.configs, hasLength(1));
      final hotkeys = t.native.configs.single['hotkeys'] as Map;
      expect(hotkeys, {'keystroke': 0x4B, 'cursor': 0x4E, 'sounds': 0x4D});
      expect(t.native.windowShows, 1);
      expect(t.controller.hotkeys.value[Feature.keystroke], HotkeyStatus.registered);
    });

    testWidgets('background launch keeps the window hidden', (tester) async {
      final t = testController();
      await t.controller.start(background: true);
      expect(t.native.windowShows, 0);
    });

    testWidgets('a shortcut toggles its feature and reconfigures native', (tester) async {
      final t = testController();
      await t.controller.start(background: true);
      t.native.emit(const ToggleRequested(Feature.cursor));
      await tester.pump();
      expect(t.controller.settings.value.cursorEnabled, isFalse);
      expect((t.native.configs.last['cursor'] as Map)['enabled'], isFalse);
      expect((t.native.configs.last['tray'] as Map)['cursor'], isFalse);
      await settle(tester);
    });

    testWidgets('disabled shortcuts are sent as 0 and conflicts are reported', (tester) async {
      final t = testController();
      t.native.hotkeyResult = {...t.native.hotkeyResult, Feature.sounds: HotkeyStatus.conflict};
      await t.controller.start(background: true);
      t.controller.settings.update((s) => s.keystrokeShortcutEnabled = false);
      await tester.pump();
      expect((t.native.configs.last['hotkeys'] as Map)['keystroke'], 0);
      expect(t.controller.hotkeys.value[Feature.sounds], HotkeyStatus.conflict);
      await settle(tester);
    });

    testWidgets('key events render the overlay and it hides after the delay', (tester) async {
      final t = testController(clock: () => now);
      await t.controller.start(background: true);
      t.controller.settings.update((s) => s.keyHideAfterMs = 1000);
      await tester.pump();

      t.native.emit(const KeyInput(Vk.lControl, down: true, modifiers: {Modifier.ctrl}));
      t.native.emit(const KeyInput(0x43, down: true, char: 'c', modifiers: {Modifier.ctrl}));
      t.native.emit(const KeyInput(0x43, down: false, modifiers: {Modifier.ctrl}));
      t.native.emit(const KeyInput(Vk.lControl, down: false, modifiers: {}));
      final last = t.native.scenes.last['strokes'] as List;
      expect((last.single as Map)['text'], 'Ctrl + C');

      final hidesBefore = t.native.hides;
      now = now.add(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(t.native.hides, hidesBefore + 1);
      expect(t.controller.composer.strokes, isEmpty);
    });

    testWidgets('turning the overlay off ignores keys and hides it', (tester) async {
      final t = testController(clock: () => now);
      await t.controller.start(background: true);
      t.controller.settings.update((s) => s.keystrokeEnabled = false);
      await tester.pump();
      final scenes = t.native.scenes.length;
      t.native.emit(const KeyInput(0x41, down: true, modifiers: {}));
      expect(t.native.scenes.length, scenes);
      expect(t.native.hides, greaterThan(0));
      expect(t.native.configs.last['keyEvents'], isFalse);
      await settle(tester);
    });

    testWidgets('sounds load the selected theme only when needed', (tester) async {
      final t = testController();
      await t.controller.start(background: true);
      expect(t.native.banks, isEmpty, reason: 'sounds are off by default');
      t.controller.settings.update((s) => s.soundsEnabled = true);
      await tester.pump();
      expect(t.native.banks, hasLength(1));
      t.controller.settings.update((s) => s.soundVolume = 0.2);
      await tester.pump();
      expect(t.native.banks, hasLength(1), reason: 'volume does not reload sounds');
      await t.controller.previewSound('bubble');
      expect(t.native.banks, hasLength(2));
      expect(t.native.sounds, 1);
      await settle(tester);
    });

    testWidgets('exit saves settings and quits', (tester) async {
      final t = testController();
      await t.controller.start(background: true);
      t.controller.settings.update((s) => s.keyScale = 120);
      await tester.runAsync(t.controller.exit);
      expect(t.native.quitCalled, isTrue);
      expect(File('${t.dir.path}/settings.json').readAsStringSync(), contains('"keyScale": 120'));
    });

    test('native config reflects settings', () {
      final s = Settings()
        ..showMouseInput = false
        ..displayId = r'\\.\DISPLAY2'
        ..cursorTemplate = 'target';
      final config = nativeConfig(s);
      expect(config['mouseEvents'], isFalse);
      expect((config['overlay'] as Map)['displayId'], r'\\.\DISPLAY2');
      expect((config['cursor'] as Map)['shape'], 4);
    });
  });

  group('settings window', () {
    Future<FakeNativeHost> pumpApp(WidgetTester tester, {void Function(Settings)? setup}) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = testController();
      if (setup != null) t.controller.settings.update(setup);
      await t.controller.start(background: true);
      await tester.pumpWidget(MonolithKeysApp(controller: t.controller));
      await tester.pumpAndSettle();
      return t.native;
    }

    AppController controllerOf(WidgetTester tester) => AppScope.of(tester.element(find.byType(Shell)));

    testWidgets('every page opens from the sidebar', (tester) async {
      await pumpApp(tester);
      for (final page in SettingsPage.values) {
        await tester.tap(find.descendant(of: find.byType(Shell), matching: find.text(page.label)).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(page.label), findsWidgets);
      }
    });

    testWidgets('toggling a switch updates settings', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Cursor highlight'));
      await tester.pump();
      expect(controllerOf(tester).settings.value.cursorEnabled, isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('restore defaults asks first', (tester) async {
      await pumpApp(tester, setup: (s) => s.keyScale = 180);
      final controller = controllerOf(tester);
      await tester.scrollUntilVisible(find.text('Restore defaults'), 200);
      await tester.tap(find.text('Restore defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.settings.value.keyScale, 180);

      await tester.tap(find.text('Restore defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(controller.settings.value.keyScale, Settings().keyScale);
    });

    testWidgets('dark theme switches the whole palette', (tester) async {
      await pumpApp(tester);
      await tester.scrollUntilVisible(find.text('Dark theme'), 200);
      await tester.tap(find.text('Dark theme'));
      await tester.pumpAndSettle();
      expect(Palette.of(tester.element(find.byType(Shell))), Palette.dark);
    });

    testWidgets('shortcut conflicts are shown next to the shortcut', (tester) async {
      final t = testController();
      t.native.hotkeyResult = {...t.native.hotkeyResult, Feature.keystroke: HotkeyStatus.conflict};
      await t.controller.start(background: true);
      await tester.pumpWidget(MonolithKeysApp(controller: t.controller));
      await tester.pumpAndSettle();
      expect(find.text('Another app is already using this shortcut.'), findsOneWidget);
    });

    testWidgets('choosing a template and colour on the Keystroke page', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Keystroke').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Soft'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.bySemanticsLabel('Soft template'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Teal keys'));
      await tester.pump();
      final s = controllerOf(tester).settings.value;
      expect((s.keyTemplate, s.keyColor), ('soft', 'teal'));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('display picker selects a display', (tester) async {
      final native = await pumpApp(tester);
      native.displayList = [...native.displayList, DisplayInfoFixtures.secondary];
      await tester.tap(find.text('Keystroke').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('^Display 2')));
      await tester.pump();
      expect(controllerOf(tester).settings.value.displayId, DisplayInfoFixtures.secondary.id);
      expect(find.textContaining('Display 2 · 2560 × 1440 · 150% scale'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('license activation is disabled without a licensing service', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('License').first);
      await tester.pumpAndSettle();
      expect(find.text('Not activated'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Activate'));
      expect(button.onPressed, isNull);
    });
  });
}
