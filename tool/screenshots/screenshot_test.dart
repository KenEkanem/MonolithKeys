// Renders every settings page to build/screenshots/ with real fonts, for
// design review without a Windows machine:
//
//   flutter test tool/screenshots/screenshot_test.dart
//
// Text uses Noto Sans (close to Segoe UI in metrics) and the real Fluent icon
// font, so layout and spacing match the app closely.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:monolithkeys/settings/settings.dart';
import 'package:monolithkeys/ui/app.dart';

import '../../test/fakes.dart';

const _uiFonts = '/usr/share/fonts/truetype/noto';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

String _packageRoot(String name) {
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map;
  final entry = (config['packages'] as List).cast<Map>().firstWhere((p) => p['name'] == name);
  return Uri.parse(entry['rootUri'] as String).toFilePath();
}

void main() {
  setUpAll(() async {
    await _loadFont('Roboto', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) '$_uiFonts/NotoSans-$w.ttf',
    ]);
    final icons = _packageRoot('fluentui_system_icons');
    for (final style in ['Regular', 'Filled']) {
      await _loadFont('packages/fluentui_system_icons/FluentSystemIcons-$style', [
        '$icons/lib/fonts/FluentSystemIcons-$style.ttf',
      ]);
    }
  });

  for (final dark in [false, true]) {
    for (final page in SettingsPage.values) {
      testWidgets('${page.name}${dark ? '-dark' : ''}', (tester) async {
        // Tall enough to show each page in full.
        tester.view.physicalSize = const Size(900 * 1.5, 1900 * 1.5);
        tester.view.devicePixelRatio = 1.5;
        addTearDown(tester.view.reset);

        final t = testController();
        t.native.displayList = [...t.native.displayList, DisplayInfoFixtures.secondary];
        t.controller.settings.update((s) => s.theme = dark ? AppTheme.dark : AppTheme.light);
        await t.controller.start(background: true);
        await tester.pumpWidget(RepaintBoundary(child: MonolithKeysApp(controller: t.controller)));
        await tester.pumpAndSettle();
        if (page != SettingsPage.general) {
          await tester.tap(find.descendant(of: find.byType(Shell), matching: find.text(page.label)).first);
          await tester.pumpAndSettle();
        }

        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/screenshots/${page.name}${dark ? '-dark' : ''}.png');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(png!.buffer.asUint8List());
        });
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
