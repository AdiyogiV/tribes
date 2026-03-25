/// Stub for path_provider package on web
/// Local file system directories are not available on web

// Re-export Directory from io_stub to avoid conflicts
export 'package:aurogram/platform/io_stub.dart' show Directory;

import 'package:aurogram/platform/io_stub.dart';

/// Get temporary directory - not supported on web
Future<Directory> getTemporaryDirectory() async {
  return Directory('/tmp');
}

/// Get application documents directory - not supported on web
Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory('/documents');
}

/// Get application support directory - not supported on web
Future<Directory> getApplicationSupportDirectory() async {
  return Directory('/support');
}

/// Get downloads directory - not supported on web
Future<Directory?> getDownloadsDirectory() async {
  return null;
}

/// Get external storage directory - not supported on web
Future<Directory?> getExternalStorageDirectory() async {
  return null;
}
