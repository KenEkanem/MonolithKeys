import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'app_controller.dart';
import 'license/license.dart';
import 'log.dart';
import 'native/native_host.dart';
import 'settings/settings_store.dart';
import 'ui/app.dart';

/// Launch argument used by the Windows startup entry.
const backgroundArg = '--background';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final roaming = Directory('${env['APPDATA'] ?? Directory.systemTemp.path}\\MonolithKeys');
  final local = Directory('${env['LOCALAPPDATA'] ?? roaming.path}\\MonolithKeys');
  Log.init(Directory('${local.path}\\logs'));
  FlutterError.onError = (details) {
    Log.error('UI error', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.error('Unhandled error', error, stack);
    return true;
  };

  final controller = AppController(
    settings: SettingsController(SettingsStore(File('${roaming.path}\\settings.json'))),
    native: MethodChannelNativeHost(),
    license: LicenseService(File('${roaming.path}\\license.json'), const UnconfiguredLicenseClient()),
  );
  runApp(MonolithKeysApp(controller: controller));
  await controller.start(background: args.contains(backgroundArg));
}
