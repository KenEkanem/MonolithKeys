import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:monolithkeys/display/display_layout.dart';
import 'package:monolithkeys/license/license.dart';

import 'fakes.dart';

void main() {
  group('display layout', () {
    const primary = DisplayInfo(
      id: r'\\.\DISPLAY1',
      bounds: Rect.fromLTWH(0, 0, 1920, 1080),
      workArea: Rect.fromLTWH(0, 0, 1920, 1040),
      scale: 1,
      primary: true,
    );
    const left = DisplayInfo(
      id: r'\\.\DISPLAY2',
      bounds: Rect.fromLTWH(-2560, -360, 2560, 1440),
      workArea: Rect.fromLTWH(-2560, -360, 2560, 1400),
      scale: 1.5,
      primary: false,
    );

    test('saved display is used while connected, otherwise the primary', () {
      expect(resolveDisplay([primary, left], left.id), left);
      expect(resolveDisplay([primary, left], r'\\.\DISPLAY9'), primary);
      expect(resolveDisplay([left, primary], null), primary);
      expect(resolveDisplay([], null), isNull);
      expect(left.number, '2');
    });

    test('overlay stays inside the area at the extremes', () {
      const area = Rect.fromLTWH(-2560, -360, 2560, 1400);
      const size = Size(400, 60);
      final topLeft = overlayOrigin(area, size, 0, 0, 24);
      final bottomRight = overlayOrigin(area, size, 1, 1, 24);
      expect(topLeft, const Offset(-2536, -336));
      expect(bottomRight, Offset(area.right - 24 - 400, area.bottom - 24 - 60));
      expect(overlayOrigin(area, size, 0.5, 0.5, 24).dx, area.center.dx - 200);
    });

    test('an overlay wider than the area is centred', () {
      final o = overlayOrigin(const Rect.fromLTWH(0, 0, 300, 300), const Size(400, 50), 1, 0, 24);
      expect(o.dx, 0);
    });

    test('preview keeps relative arrangement and fits the box', () {
      final rects = previewLayout([primary, left], const Size(400, 200), gap: 0);
      expect(rects[left.id]!.right, closeTo(rects[primary.id]!.left, 0.001));
      expect(rects[left.id]!.width / rects[primary.id]!.width, closeTo(2560 / 1920, 0.001));
      for (final r in rects.values) {
        expect(const Rect.fromLTWH(0, 0, 400, 200).contains(r.topLeft), isTrue);
        expect(r.right, lessThanOrEqualTo(400.001));
        expect(r.bottom, lessThanOrEqualTo(200.001));
      }
    });
  });

  group('license', () {
    late Directory dir;
    late File file;
    var now = DateTime(2026, 11, 23);
    setUp(() {
      dir = Directory.systemTemp.createTempSync('mk_license');
      file = File('${dir.path}/license.json');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    LicenseService service(LicenseClient client) => LicenseService(file, client, clock: () => now);

    test('key format check accepts pasted keys and rejects junk', () {
      expect(LicenseService.isWellFormed(' mk-abcde-12345-fghij-67890 '), isTrue);
      expect(LicenseService.isWellFormed('MK-ABCDE-12345'), isFalse);
      expect(LicenseService.isWellFormed('XX-ABCDE-12345-FGHIJ-67890'), isFalse);
    });

    test('without a licensing service, activation never succeeds', () async {
      final s = service(const UnconfiguredLicenseClient());
      expect(s.canActivateOnline, isFalse);
      expect(await s.activate('MK-ABCDE-12345-FGHIJ-67890'), UnconfiguredLicenseClient.message);
      expect(s.state.status, LicenseStatus.unlicensed);
      expect(file.existsSync(), isFalse);
    });

    test('malformed keys are rejected before contacting the service', () async {
      final client = FakeLicenseClient(const Activated());
      expect(await service(client).activate('hello'), contains('MK-XXXXX'));
    });

    test('activation persists, masks the key and can be deactivated', () async {
      final client = FakeLicenseClient(Activated(expiresAt: DateTime(2027)));
      final s = service(client);
      expect(await s.activate('MK-ABCDE-12345-FGHIJ-67890'), isNull);
      expect(s.state.status, LicenseStatus.active);
      expect(s.state.maskedKey, endsWith('67890'));
      expect(s.state.maskedKey, isNot(contains('ABCDE')));
      expect(service(client).state.status, LicenseStatus.active, reason: 'reloaded from disk');

      await s.deactivate();
      expect(client.deactivated, ['MK-ABCDE-12345-FGHIJ-67890']);
      expect(s.state.status, LicenseStatus.unlicensed);
      expect(file.existsSync(), isFalse);
    });

    test('a stored license past its expiry loads as expired', () async {
      final s = service(FakeLicenseClient(Activated(expiresAt: DateTime(2026, 12, 1))));
      await s.activate('MK-ABCDE-12345-FGHIJ-67890');
      now = DateTime(2027);
      expect(service(const UnconfiguredLicenseClient()).state.status, LicenseStatus.expired);
      now = DateTime(2026, 11, 23);
    });

    test('rejections and already-expired activations report a message', () async {
      final client = FakeLicenseClient(const Rejected('This key has been revoked.'));
      final s = service(client);
      expect(await s.activate('MK-ABCDE-12345-FGHIJ-67890'), 'This key has been revoked.');
      client.result = Activated(expiresAt: DateTime(2020));
      expect(await s.activate('MK-ABCDE-12345-FGHIJ-67890'), contains('expired'));
      expect(s.state.status, LicenseStatus.unlicensed);
    });

    test('an unreadable license file is treated as unlicensed', () {
      file.writeAsStringSync('garbage');
      expect(service(const UnconfiguredLicenseClient()).state.status, LicenseStatus.unlicensed);
    });
  });
}
