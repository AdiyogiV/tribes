import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Very lightweight file sink for logs (opt-in).
///
/// - Disabled by default (enable via [setEnabled])
/// - No-op on web
/// - Best-effort (never throws)
/// - Size-based rotation (default 10MB) and retention (default 7 files)
class LogFileSink {
  static bool _enabled = false;

  static const int _maxBytes = 10 * 1024 * 1024; // 10MB
  static const int _maxRotatedFiles = 7;

  static Future<void>? _initFuture;
  static File? _activeFile;
  static Directory? _dir;

  // Serialize writes to preserve ordering without blocking UI.
  static Future<void> _writeChain = Future.value();

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static bool get enabled => _enabled;

  static Future<void> writeLine(String line) {
    if (!_enabled || kIsWeb) return Future.value();

    _writeChain = _writeChain.then((_) async {
      try {
        await _ensureInitialized();
        final file = _activeFile;
        if (file == null) return;

        await _rotateIfNeeded(file);

        // Append with newline.
        await file.writeAsString('$line\n', mode: FileMode.append, flush: false);
      } catch (_) {
        // Swallow all errors - logging must never crash the app.
      }
    });

    return _writeChain;
  }

  static Future<void> _ensureInitialized() async {
    _initFuture ??= () async {
      try {
        final base = await getApplicationSupportDirectory();
        final dir = Directory('${base.path}/logs');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        _dir = dir;
        _activeFile = File('${dir.path}/aurogram.log');
        // Ensure file exists.
        if (!await _activeFile!.exists()) {
          await _activeFile!.create(recursive: true);
        }
      } catch (_) {
        _dir = null;
        _activeFile = null;
      }
    }();

    await _initFuture;
  }

  static Future<void> _rotateIfNeeded(File file) async {
    try {
      final stat = await file.stat();
      if (stat.size < _maxBytes) return;

      final dir = _dir;
      if (dir == null) return;

      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('.', '');
      final rotated = File('${dir.path}/aurogram-$ts.log');

      // Rename current file to rotated name; create fresh active file.
      if (await file.exists()) {
        await file.rename(rotated.path);
      }
      _activeFile = File('${dir.path}/aurogram.log');
      await _activeFile!.create(recursive: true);

      await _enforceRetention(dir);
    } catch (_) {
      // Ignore rotation errors.
    }
  }

  static Future<void> _enforceRetention(Directory dir) async {
    try {
      final entries = await dir.list().toList();
      final rotated = <FileSystemEntity>[];
      for (final e in entries) {
        if (e is File &&
            e.path.contains('aurogram-') &&
            e.path.endsWith('.log')) {
          rotated.add(e);
        }
      }

      rotated.sort((a, b) {
        try {
          return b.statSync().modified.compareTo(a.statSync().modified);
        } catch (_) {
          return 0;
        }
      });

      if (rotated.length <= _maxRotatedFiles) return;

      for (final e in rotated.sublist(_maxRotatedFiles)) {
        try {
          await e.delete();
        } catch (_) {}
      }
    } catch (_) {
      // Ignore retention errors.
    }
  }
}

