import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/media/file_uploader.dart';

/// Cross-platform media upload helper
/// Handles file uploads using bytes on web and file paths on mobile
class MediaUploadHelper {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload bytes to Firebase Storage (works on all platforms)
  /// This is the preferred method for web uploads
  static Future<String?> uploadBytes({
    required Uint8List bytes,
    required String storagePath,
    String? contentType,
    Function(double)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child(storagePath);
      
      final metadata = contentType != null 
          ? SettableMetadata(contentType: contentType) 
          : null;
      
      final uploadTask = ref.putData(bytes, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = _calculateProgress(snapshot);
          onProgress(progress);
        });
      }

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      
      AppLogger.d('Upload complete', 
          category: LogCategory.media, 
          data: {'path': storagePath, 'size': bytes.length});
      
      return downloadUrl;
    } catch (e, stack) {
      AppLogger.e('Upload failed', 
          category: LogCategory.media, 
          error: e, 
          stackTrace: stack);
      return null;
    }
  }

  /// Upload from XFile (cross-platform image_picker result)
  /// Reads bytes from XFile and uploads using putData
  static Future<String?> uploadXFile({
    required dynamic xFile, // XFile from image_picker
    required String storagePath,
    String? contentType,
    Function(double)? onProgress,
  }) async {
    try {
      final Uint8List bytes = await xFile.readAsBytes();
      
      // Auto-detect content type from name if not provided
      String? effectiveContentType = contentType;
      if (effectiveContentType == null) {
        final name = (xFile.name ?? xFile.path ?? '').toString().toLowerCase();
        effectiveContentType = _getContentType(name);
      }
      
      return await uploadBytes(
        bytes: bytes,
        storagePath: storagePath,
        contentType: effectiveContentType,
        onProgress: onProgress,
      );
    } catch (e, stack) {
      AppLogger.e('XFile upload failed', 
          category: LogCategory.media, 
          error: e, 
          stackTrace: stack);
      return null;
    }
  }

  /// Upload from file path (mobile only)
  /// On web, this will fail - use uploadBytes or uploadXFile instead
  static Future<String?> uploadFromPath({
    required String filePath,
    required String storagePath,
    Function(double)? onProgress,
  }) async {
    if (kIsWeb) {
      AppLogger.e('uploadFromPath not supported on web - use uploadBytes or uploadXFile',
          category: LogCategory.media);
      return null;
    }
    
    return await FileUploader.uploadFromPath(
      filePath: filePath,
      storagePath: storagePath,
      onProgress: onProgress,
    );
  }

  /// Smart upload - automatically chooses best method based on input
  /// Accepts: XFile, Uint8List, or String (file path on mobile)
  static Future<String?> smartUpload({
    required dynamic source,
    required String storagePath,
    String? contentType,
    Function(double)? onProgress,
  }) async {
    if (source is Uint8List) {
      return await uploadBytes(
        bytes: source,
        storagePath: storagePath,
        contentType: contentType,
        onProgress: onProgress,
      );
    }
    
    // Check if it's an XFile (has readAsBytes method)
    if (source != null && source.readAsBytes != null) {
      try {
        return await uploadXFile(
          xFile: source,
          storagePath: storagePath,
          contentType: contentType,
          onProgress: onProgress,
        );
      } catch (_) {
        // Fall through to path handling
      }
    }
    
    // Assume it's a file path (String)
    if (source is String && !kIsWeb) {
      return await uploadFromPath(
        filePath: source,
        storagePath: storagePath,
        onProgress: onProgress,
      );
    }
    
    AppLogger.e('Unsupported upload source type: ${source.runtimeType}',
        category: LogCategory.media);
    return null;
  }

  /// Calculate upload progress percentage
  static double _calculateProgress(TaskSnapshot snapshot) {
    double progress = 0.0;
    final total = snapshot.totalBytes;
    if (total > 0) {
      progress = (snapshot.bytesTransferred / total) * 100.0;
    } else if (snapshot.bytesTransferred > 0) {
      progress = 1.0;
    }
    return progress.clamp(0.0, 100.0);
  }

  /// Get content type from file extension
  static String? _getContentType(String name) {
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (name.endsWith('.png')) {
      return 'image/png';
    } else if (name.endsWith('.gif')) {
      return 'image/gif';
    } else if (name.endsWith('.webp')) {
      return 'image/webp';
    } else if (name.endsWith('.mp4')) {
      return 'video/mp4';
    } else if (name.endsWith('.mov')) {
      return 'video/quicktime';
    } else if (name.endsWith('.webm')) {
      return 'video/webm';
    } else if (name.endsWith('.m4a')) {
      return 'audio/m4a';
    } else if (name.endsWith('.mp3')) {
      return 'audio/mpeg';
    } else if (name.endsWith('.wav')) {
      return 'audio/wav';
    }
    return null;
  }
}
