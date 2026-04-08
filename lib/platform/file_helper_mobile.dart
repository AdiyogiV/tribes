/// Mobile implementation of file helpers using dart:io
library;

import 'dart:io' as io;
import 'dart:typed_data';

/// Create a dart:io File from path - only works on mobile
io.File createIOFile(String path) => io.File(path);

/// Check if file exists at path
Future<bool> fileExists(String path) async {
  return io.File(path).exists();
}

/// Check if file exists at path (sync)
bool fileExistsSync(String path) {
  return io.File(path).existsSync();
}

/// Read file as bytes
Future<Uint8List> readFileAsBytes(String path) async {
  return io.File(path).readAsBytes();
}

/// Write bytes to file
Future<void> writeFileAsBytes(String path, Uint8List bytes) async {
  await io.File(path).writeAsBytes(bytes);
}

/// Delete file at path
Future<void> deleteFile(String path) async {
  final file = io.File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

/// Copy file to new path
Future<void> copyFile(String sourcePath, String destPath) async {
  await io.File(sourcePath).copy(destPath);
}

/// Create directory
Future<void> createDirectory(String path, {bool recursive = false}) async {
  await io.Directory(path).create(recursive: recursive);
}

/// Check if directory exists
Future<bool> directoryExists(String path) async {
  return io.Directory(path).exists();
}

/// Get file length
Future<int> getFileLength(String path) async {
  return io.File(path).length();
}
