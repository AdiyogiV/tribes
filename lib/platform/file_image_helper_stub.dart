import 'package:flutter/widgets.dart';

/// Web stub for file image helper
/// Returns null since web cannot access local files

/// Try to load an image from a local file path
/// Returns null on web
ImageProvider? getFileImage(String path) {
  // Local file access not available on web
  return null;
}

/// Check if a local file exists
/// Returns false on web
bool localFileExists(String path) {
  return false;
}
