/// Web stub implementation of file helpers
/// File system operations are not available on web
library;

import 'dart:typed_data';

/// Stub - file operations not supported on web
/// Returns a minimal stub object that can be used for type checking
/// but will throw if actually used
dynamic createIOFile(String path) {
  throw UnsupportedError('File operations are not supported on web');
}

/// Stub - always returns false on web
Future<bool> fileExists(String path) async => false;

/// Stub - always returns false on web
bool fileExistsSync(String path) => false;

/// Stub - returns empty bytes on web
Future<Uint8List> readFileAsBytes(String path) async => Uint8List(0);

/// Stub - no-op on web
Future<void> writeFileAsBytes(String path, Uint8List bytes) async {}

/// Stub - no-op on web
Future<void> deleteFile(String path) async {}

/// Stub - no-op on web
Future<void> copyFile(String sourcePath, String destPath) async {}

/// Stub - no-op on web
Future<void> createDirectory(String path, {bool recursive = false}) async {}

/// Stub - always returns false on web
Future<bool> directoryExists(String path) async => false;

/// Stub - returns 0 on web
Future<int> getFileLength(String path) async => 0;
