import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Stub file uploader for web - only supports bytes upload
class FileUploader {
  /// Upload from file path - NOT supported on web
  static Future<String?> uploadFromPath({
    required String filePath,
    required String storagePath,
    Function(double)? onProgress,
  }) async {
    // Web cannot access file paths
    throw UnsupportedError('File path uploads not supported on web. Use uploadBytes instead.');
  }

  /// Check if file exists at path - NOT supported on web
  static Future<bool> fileExists(String path) async {
    return false;
  }

  /// Read file as bytes - NOT supported on web  
  static Future<Uint8List?> readFileAsBytes(String path) async {
    return null;
  }

  /// Copy file to new location - NOT supported on web
  static Future<String?> copyFile(String sourcePath, String destPath) async {
    return null;
  }
  
  /// Delete file - NOT supported on web
  static Future<bool> deleteFile(String path) async {
    return false;
  }
}
