import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../log.dart';

enum LicenseStatus { unlicensed, active, expired }

/// Outcome of asking the licensing service to activate a key.
sealed class ActivationResult {
  const ActivationResult();
}

class Activated extends ActivationResult {
  const Activated({this.expiresAt});

  /// Null for perpetual licenses.
  final DateTime? expiresAt;
}

class Rejected extends ActivationResult {
  const Rejected(this.message);

  final String message;
}

class ServiceUnavailable extends ActivationResult {
  const ServiceUnavailable(this.message);

  final String message;
}

/// Contract for the licensing backend. Implement this against the real API
/// once it exists and pass it to [LicenseService].
abstract interface class LicenseClient {
  bool get isConfigured;

  Future<ActivationResult> activate(String key, {required String device});

  Future<void> deactivate(String key, {required String device});
}

/// Used until a licensing server is available. It never reports success.
class UnconfiguredLicenseClient implements LicenseClient {
  const UnconfiguredLicenseClient();

  static const message = 'Online activation is not available in this version of MonolithKeys yet.';

  @override
  bool get isConfigured => false;

  @override
  Future<ActivationResult> activate(String key, {required String device}) async => const ServiceUnavailable(message);

  @override
  Future<void> deactivate(String key, {required String device}) async {}
}

class LicenseState {
  const LicenseState(this.status, {this.key, this.expiresAt});

  static const none = LicenseState(LicenseStatus.unlicensed);

  final LicenseStatus status;
  final String? key;
  final DateTime? expiresAt;

  /// Shows only the last group so the key is not readable over a shoulder.
  String? get maskedKey => key == null ? null : 'MK-•••••-•••••-•••••-${key!.substring(key!.length - 5)}';
}

/// Tracks the activated license and stores it in `license.json`.
///
/// All features work without a license. This only manages license state, so a
/// future release can connect a real [LicenseClient] without UI changes.
class LicenseService extends ChangeNotifier {
  LicenseService(this._file, this._client, {DateTime Function()? clock}) : _now = clock ?? DateTime.now {
    _state = _load();
  }

  final File _file;
  final LicenseClient _client;
  final DateTime Function() _now;
  late LicenseState _state;

  LicenseState get state => _state;
  bool get canActivateOnline => _client.isConfigured;

  static final _keyPattern = RegExp(r'^MK(-[A-Z0-9]{5}){4}$');

  /// Uppercases and strips spaces so pasted keys still match.
  static String normalize(String key) => key.toUpperCase().replaceAll(RegExp(r'\s'), '');

  static bool isWellFormed(String key) => _keyPattern.hasMatch(normalize(key));

  /// Returns null on success, otherwise a message for the user.
  Future<String?> activate(String rawKey) async {
    final key = normalize(rawKey);
    if (!isWellFormed(key)) return 'That doesn\'t look like a license key. Keys look like MK-XXXXX-XXXXX-XXXXX-XXXXX.';
    final result = await _client.activate(key, device: Platform.localHostname);
    switch (result) {
      case Activated(:final expiresAt):
        if (expiresAt != null && expiresAt.isBefore(_now())) return 'This license expired on ${_date(expiresAt)}.';
        _set(LicenseState(LicenseStatus.active, key: key, expiresAt: expiresAt));
        return null;
      case Rejected(:final message) || ServiceUnavailable(:final message):
        return message;
    }
  }

  Future<void> deactivate() async {
    final key = _state.key;
    if (key == null) return;
    try {
      await _client.deactivate(key, device: Platform.localHostname);
    } on Object catch (e) {
      Log.error('License deactivation request failed; removing the local license anyway', e);
    }
    _set(LicenseState.none);
  }

  LicenseState _load() {
    if (!_file.existsSync()) return LicenseState.none;
    try {
      final json = jsonDecode(_file.readAsStringSync()) as Map<String, Object?>;
      final key = json['key'] as String;
      if (!isWellFormed(key)) return LicenseState.none;
      final expires = json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String);
      final expired = expires != null && expires.isBefore(_now());
      return LicenseState(expired ? LicenseStatus.expired : LicenseStatus.active, key: key, expiresAt: expires);
    } on Object catch (e) {
      Log.error('License file unreadable; treating as unlicensed', e);
      return LicenseState.none;
    }
  }

  void _set(LicenseState state) {
    _state = state;
    try {
      if (state.key == null) {
        if (_file.existsSync()) _file.deleteSync();
      } else {
        _file.parent.createSync(recursive: true);
        _file.writeAsStringSync(jsonEncode({'key': state.key, 'expiresAt': state.expiresAt?.toIso8601String()}));
      }
    } on FileSystemException catch (e) {
      Log.error('Saving license failed', e);
    }
    notifyListeners();
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
