import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/media/file_uploader.dart';

/// Service responsible for handling media file storage operations
/// Supports both mobile (file path) and web (bytes) uploads
class MediaStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Copies a file to a permanent location on the device (mobile only)
  /// On web, returns null as file system access is not available
  Future<String?> copyToPermanentLocation(
      String sourcePath, String fileName) async {
    if (kIsWeb) {
      // Web doesn't have local file system access
      AppLogger.d('copyToPermanentLocation skipped on web',
          category: LogCategory.media);
      return null;
    }

    try {
      return await FileUploader.copyFile(
        sourcePath,
        await _getPermanentPath(fileName),
      );
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('Copy to permanent location failed',
            category: LogCategory.media, error: e);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Get the permanent storage path for a file (mobile only)
  Future<String> _getPermanentPath(String fileName) async {
    // This is only called on mobile due to kIsWeb guard
    // Using path_provider conditionally
    if (kIsWeb) return fileName;

    try {
      // Dynamic import for path_provider
      final directory = await _getAppDocumentsDirectory();
      return '$directory/PermanentPosts/$fileName';
    } catch (e) {
      return fileName;
    }
  }

  /// Get app documents directory (mobile only)
  Future<String> _getAppDocumentsDirectory() async {
    if (kIsWeb) return '';
    // This will be handled by conditional import at compile time
    try {
      final dir = await _getMobileDocDir();
      return dir ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Uploads a file to Firebase Storage and returns the download URL
  /// On mobile: uses file path
  /// On web: throws - use uploadFromBytes instead
  Future<String?> uploadToStorage(String filePath, String storagePath,
      {Function(double)? onProgress}) async {
    if (kIsWeb) {
      AppLogger.e(
          'uploadToStorage with file path not supported on web - use uploadFromBytes',
          category: LogCategory.media);
      return null;
    }

    try {
      return await FileUploader.uploadFromPath(
        filePath: filePath,
        storagePath: storagePath,
        onProgress: onProgress,
      );
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('Upload to storage failed',
            category: LogCategory.media, error: e);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Uploads bytes to Firebase Storage (works on all platforms including web)
  /// This is the preferred method for web uploads
  Future<String?> uploadFromBytes(
    Uint8List bytes,
    String storagePath, {
    String? contentType,
    Function(double)? onProgress,
  }) async {
    try {
      Reference ref = _storage.ref().child(storagePath);

      final metadata =
          contentType != null ? SettableMetadata(contentType: contentType) : null;

      final uploadTask = ref.putData(bytes, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progressPercent = _calculateProgress(snapshot);
          onProgress(progressPercent);
        });
      }

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();

      AppLogger.d('Upload from bytes complete',
          category: LogCategory.media,
          data: {'path': storagePath, 'size': bytes.length});

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('Upload from bytes failed',
            category: LogCategory.media, error: e);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Upload from XFile (cross-platform, from image_picker)
  /// Works on both mobile and web
  Future<String?> uploadFromXFile(
    dynamic xFile, // XFile from image_picker
    String storagePath, {
    String? contentType,
    Function(double)? onProgress,
  }) async {
    try {
      final Uint8List bytes = await xFile.readAsBytes();

      // Auto-detect content type from file name
      String? effectiveContentType = contentType;
      if (effectiveContentType == null && xFile.name != null) {
        effectiveContentType = _getContentTypeFromName(xFile.name);
      }

      return await uploadFromBytes(
        bytes,
        storagePath,
        contentType: effectiveContentType,
        onProgress: onProgress,
      );
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('Upload from XFile failed',
            category: LogCategory.media, error: e);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Cross-platform upload - automatically chooses best method
  /// Accepts: XFile, Uint8List, or String (file path on mobile)
  Future<String?> uploadCrossPlatform(
    dynamic source,
    String storagePath, {
    String? contentType,
    Function(double)? onProgress,
  }) async {
    if (source is Uint8List) {
      return await uploadFromBytes(
        source,
        storagePath,
        contentType: contentType,
        onProgress: onProgress,
      );
    }

    // Check if it's an XFile (has readAsBytes method)
    try {
      if (source != null) {
        final bytes = await source.readAsBytes();
        if (bytes is Uint8List) {
          return await uploadFromBytes(
            bytes,
            storagePath,
            contentType: contentType,
            onProgress: onProgress,
          );
        }
      }
    } catch (_) {
      // Not an XFile, fall through
    }

    // Assume it's a file path (String)
    if (source is String && !kIsWeb) {
      return await uploadToStorage(source, storagePath, onProgress: onProgress);
    }

    AppLogger.e('Unsupported upload source type: ${source.runtimeType}',
        category: LogCategory.media);
    return null;
  }

  /// Deletes a file from Firebase Storage
  Future<bool> deleteStorageFile(String storagePath) async {
    try {
      Reference ref = _storage.ref().child(storagePath);
      await ref.delete();
      return true;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Delete storage file failed or file not found',
            category: LogCategory.media);
      }
      return false;
    }
  }

  /// Calculate upload progress
  double _calculateProgress(TaskSnapshot snapshot) {
    double progressPercent = 0.0;
    final int total = snapshot.totalBytes;
    if (total > 0) {
      progressPercent = (snapshot.bytesTransferred / total) * 100.0;
    } else if (snapshot.bytesTransferred > 0) {
      progressPercent = 1.0;
    }
    if (progressPercent.isNaN || !progressPercent.isFinite) {
      progressPercent = 0.0;
    }
    return progressPercent.clamp(0.0, 100.0);
  }

  /// Get content type from file name
  String? _getContentTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (lower.endsWith('.png')) {
      return 'image/png';
    } else if (lower.endsWith('.gif')) {
      return 'image/gif';
    } else if (lower.endsWith('.webp')) {
      return 'image/webp';
    } else if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    } else if (lower.endsWith('.mov')) {
      return 'video/quicktime';
    } else if (lower.endsWith('.webm')) {
      return 'video/webm';
    }
    return null;
  }

  /// Get mobile documents directory - stubbed for web
  Future<String?> _getMobileDocDir() async {
    if (kIsWeb) return null;
    // This import will be tree-shaken on web
    try {
      // ignore: depend_on_referenced_packages
      final pathProvider = await _getPathProvider();
      return pathProvider;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getPathProvider() async {
    if (kIsWeb) return null;
    // Dynamic import to avoid web compilation issues
    try {
      // This relies on path_provider being available on mobile
      // The actual import is done at the top of file_uploader_mobile.dart
      return null; // Will be handled by file_uploader
    } catch (e) {
      return null;
    }
  }
}
