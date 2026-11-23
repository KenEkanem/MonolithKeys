import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:monolithkeys/app_controller.dart';
import 'package:monolithkeys/display/display_layout.dart';
import 'package:monolithkeys/license/license.dart';
import 'package:monolithkeys/native/native_host.dart';
import 'package:monolithkeys/settings/settings_store.dart';

/// Records every call the app makes to the Windows layer.
class FakeNativeHost implements NativeHost {
  final _events = StreamController<NativeEvent>.broadcast(sync: true);
  final configs = <Map<String, Object?>>[];
  final scenes = <Map<String, Object?>>[];
  final banks = <List<List<Uint8List>>>[];
  int hides = 0;
  int sounds = 0;
  int windowShows = 0;
  int windowHides = 0;
  bool quitCalled = false;
  Map<Feature, HotkeyStatus> hotkeyResult = {for (final f in Feature.values) f: HotkeyStatus.registered};
  List<DisplayInfo> displayList = const [
    DisplayInfo(
      id: r'\\.\DISPLAY1',
      bounds: Rect.fromLTWH(0, 0, 1920, 1080),
      workArea: Rect.fromLTWH(0, 0, 1920, 1040),
      scale: 1,
      primary: true,
    ),
  ];

  void emit(NativeEvent e) => _events.add(e);

  @override
  Stream<NativeEvent> get events => _events.stream;

  @override
  Future<Map<Feature, HotkeyStatus>> configure(Map<String, Object?> config) async {
    configs.add(config);
    return hotkeyResult;
  }

  @override
  Future<void> setSoundBank(List<List<Uint8List>> bank) async => banks.add(bank);

  @override
  Future<void> playSound() async => sounds++;

  @override
  Future<void> showKeystrokes(Map<String, Object?> scene) async => scenes.add(scene);

  @override
  Future<void> hideKeystrokes() async => hides++;

  @override
  Future<List<DisplayInfo>> displays() async => displayList;

  @override
  Future<String?> wallpaperPath() async => null;

  @override
  Future<void> showWindow() async => windowShows++;

  @override
  Future<void> hideWindow() async => windowHides++;

  @override
  Future<void> startWindowDrag() async {}

  @override
  Future<void> open(String target) async {}

  @override
  Future<void> quit() async => quitCalled = true;
}

class FakeLicenseClient implements LicenseClient {
  FakeLicenseClient(this.result);

  ActivationResult result;
  final deactivated = <String>[];

  @override
  bool get isConfigured => true;

  @override
  Future<ActivationResult> activate(String key, {required String device}) async => result;

  @override
  Future<void> deactivate(String key, {required String device}) async => deactivated.add(key);
}

/// A controller wired to fakes and a throwaway settings folder.
({AppController controller, FakeNativeHost native, Directory dir}) testController({
  DateTime Function()? clock,
  LicenseClient license = const UnconfiguredLicenseClient(),
}) {
  final dir = Directory.systemTemp.createTempSync('monolithkeys_test');
  final native = FakeNativeHost();
  final controller = AppController(
    settings: SettingsController(SettingsStore(File('${dir.path}/settings.json')), saveDelay: Duration.zero),
    native: native,
    license: LicenseService(File('${dir.path}/license.json'), license),
    clock: clock,
  );
  return (controller: controller, native: native, dir: dir);
}

abstract final class DisplayInfoFixtures {
  static const secondary = DisplayInfo(
    id: r'\\.\DISPLAY2',
    bounds: Rect.fromLTWH(1920, 0, 2560, 1440),
    workArea: Rect.fromLTWH(1920, 0, 2560, 1400),
    scale: 1.5,
    primary: false,
  );
}
