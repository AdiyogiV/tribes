import 'dart:io';
import 'package:flutter/widgets.dart';

/// Mobile implementation for file image helper
/// Can access local files on iOS and Android

/// Try to load an image from a local file path
/// Returns FileImage if file exists, null otherwise
ImageProvider? getFileImage(String path) {
  try {
    final cleanPath = path.startsWith('file://') ? path.substring(7) : path;
    if (cleanPath.isEmpty) return null;
    
    final file = File(cleanPath);
    if (file.existsSync()) {
      return FileImage(file);
    }
  } catch (e) {
    // Ignore file access errors
  }
  return null;
}

/// Check if a local file exists
bool localFileExists(String path) {
  try {
    final cleanPath = path.startsWith('file://') ? path.substring(7) : path;
    if (cleanPath.isEmpty) return false;
    
    return File(cleanPath).existsSync();
  } catch (e) {
    return false;
  }
}
