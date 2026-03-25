import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Mobile file uploader - supports file path operations
class FileUploader {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload from file path (mobile only)
  static Future<String?> uploadFromPath({
    required String filePath,
    required String storagePath,
    Function(double)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.e('File not found: $filePath', category: LogCategory.media);
        return null;
      }

      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(file);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress = 0.0;
          final total = snapshot.totalBytes;
          if (total > 0) {
            progress = (snapshot.bytesTransferred / total) * 100.0;
          } else if (snapshot.bytesTransferred > 0) {
            progress = 1.0;
          }
          onProgress(progress.clamp(0.0, 100.0));
        });
      }

      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e, stack) {
      AppLogger.e('Upload from path failed',
          category: LogCategory.media, error: e, stackTrace: stack);
      return null;
    }
  }

  /// Check if file exists at path
  static Future<bool> fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }

  /// Read file as bytes
  static Future<Uint8List?> readFileAsBytes(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      AppLogger.e('Failed to read file as bytes',
          category: LogCategory.media, error: e);
      return null;
    }
  }

  /// Copy file to new location
  static Future<String?> copyFile(String sourcePath, String destPath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return null;

      // Ensure destination directory exists
      final destDir = Directory(destPath).parent;
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      final copied = await source.copy(destPath);
      return copied.path;
    } catch (e) {
      AppLogger.e('Failed to copy file',
          category: LogCategory.media, error: e);
      return null;
    }
  }

  /// Delete file
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
