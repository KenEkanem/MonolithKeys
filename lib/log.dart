import 'dart:io';

/// Plain-text diagnostic log, one file per day, kept for a week.
///
/// Only app lifecycle and error information belongs here. Never log key codes,
/// characters or anything else derived from what the user types.
class Log {
  static Directory? _dir;
  static const _keepDays = 7;

  static Directory? get directory => _dir;

  static void init(Directory dir) {
    _dir = dir;
    try {
      dir.createSync(recursive: true);
      final cutoff = DateTime.now().subtract(const Duration(days: _keepDays));
      for (final f in dir.listSync().whereType<File>()) {
        if (f.path.endsWith('.log') && f.lastModifiedSync().isBefore(cutoff)) f.deleteSync();
      }
    } on FileSystemException {
      _dir = null;
    }
  }

  static void info(String message) => _write('INFO', message);

  static void error(String message, [Object? error, StackTrace? stack]) =>
      _write('ERROR', [message, ?error?.toString(), ?stack?.toString()].join('\n'));

  static void _write(String level, String message) {
    final dir = _dir;
    if (dir == null) return;
    final now = DateTime.now();
    final day = now.toIso8601String().substring(0, 10).replaceAll('-', '');
    try {
      File('${dir.path}${Platform.pathSeparator}monolithkeys-$day.log')
          .writeAsStringSync('${now.toIso8601String()} $level $message\n', mode: FileMode.append);
    } on FileSystemException {
      // Logging must never take the app down.
    }
  }
}
