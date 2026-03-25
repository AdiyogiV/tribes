// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:aurogram/utils/logging/app_logger.dart';

/// Web implementation for generating video thumbnails using HTML5 canvas
class VideoThumbnailWeb {
  /// Generate a thumbnail from a video URL or blob URL
  /// Returns JPEG bytes or null on failure
  static Future<Uint8List?> generateThumbnail(String videoSource) async {
    try {
      AppLogger.d('Generating web video thumbnail', 
          category: LogCategory.media, 
          data: {'source': videoSource.substring(0, 50)});

      // Create video element
      final video = web.HTMLVideoElement()
        ..crossOrigin = 'anonymous'
        ..muted = true
        ..preload = 'metadata';
      
      // Set source
      video.src = videoSource;
      
      // Wait for metadata to load
      final metadataCompleter = Completer<void>();
      
      video.onloadedmetadata = (web.Event e) {
        if (!metadataCompleter.isCompleted) {
          metadataCompleter.complete();
        }
      }.toJS;
      
      video.onerror = (web.Event e) {
        if (!metadataCompleter.isCompleted) {
          metadataCompleter.completeError('Video load error');
        }
      }.toJS;
      
      // Start loading
      video.load();
      
      // Wait for metadata with timeout
      await metadataCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Video metadata load timeout'),
      );
      
      // Seek to 1 second or 10% of video duration (whichever is less)
      final seekTime = video.duration > 10 ? 1.0 : video.duration * 0.1;
      video.currentTime = seekTime;
      
      // Wait for seek to complete
      final seekCompleter = Completer<void>();
      
      video.onseeked = (web.Event e) {
        if (!seekCompleter.isCompleted) {
          seekCompleter.complete();
        }
      }.toJS;
      
      await seekCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Video seek timeout'),
      );
      
      // Get video dimensions
      final videoWidth = video.videoWidth;
      final videoHeight = video.videoHeight;
      
      if (videoWidth == 0 || videoHeight == 0) {
        AppLogger.w('Video has invalid dimensions', category: LogCategory.media);
        return null;
      }
      
      // Calculate thumbnail size (max 512px while maintaining aspect ratio)
      const maxSize = 512;
      int thumbWidth = videoWidth;
      int thumbHeight = videoHeight;
      
      if (videoWidth > maxSize || videoHeight > maxSize) {
        if (videoWidth > videoHeight) {
          thumbWidth = maxSize;
          thumbHeight = (videoHeight * maxSize / videoWidth).round();
        } else {
          thumbHeight = maxSize;
          thumbWidth = (videoWidth * maxSize / videoHeight).round();
        }
      }
      
      // Create canvas and draw video frame
      final canvas = web.HTMLCanvasElement()
        ..width = thumbWidth
        ..height = thumbHeight;
      
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImageScaled(video, 0, 0, thumbWidth.toDouble(), thumbHeight.toDouble());
      
      // Convert to blob
      final blobCompleter = Completer<Uint8List?>();
      
      canvas.toBlob((web.Blob? blob) {
        if (blob == null) {
          blobCompleter.complete(null);
          return;
        }
        
        // Read blob as array buffer
        final reader = web.FileReader();
        
        reader.onload = (web.Event e) {
          final result = reader.result;
          if (result != null) {
            final arrayBuffer = result as JSArrayBuffer;
            final bytes = arrayBuffer.toDart.asUint8List();
            blobCompleter.complete(bytes);
          } else {
            blobCompleter.complete(null);
          }
        }.toJS;
        
        reader.onerror = (web.Event e) {
          blobCompleter.complete(null);
        }.toJS;
        
        reader.readAsArrayBuffer(blob);
      }.toJS, 'image/jpeg', 0.85.toJS);
      
      final bytes = await blobCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      
      // Cleanup
      video.src = '';
      video.load();
      
      if (bytes != null) {
        AppLogger.i('Web video thumbnail generated', 
            category: LogCategory.media,
            data: {'size': bytes.length, 'width': thumbWidth, 'height': thumbHeight});
      }
      
      return bytes;
    } catch (e) {
      AppLogger.e('Failed to generate web video thumbnail', 
          category: LogCategory.media, error: e);
      return null;
    }
  }

  /// Generate thumbnail from XFile (for picked videos)
  /// Creates a blob URL from the file and generates thumbnail
  static Future<Uint8List?> generateThumbnailFromFile(dynamic xFile) async {
    try {
      // Get file bytes
      final bytes = await xFile.readAsBytes() as Uint8List;
      
      // Create blob from bytes
      final jsArray = bytes.toJS;
      final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'video/mp4'));
      
      // Create blob URL
      final blobUrl = web.URL.createObjectURL(blob);
      
      try {
        // Generate thumbnail
        final thumbnail = await generateThumbnail(blobUrl);
        return thumbnail;
      } finally {
        // Cleanup blob URL
        web.URL.revokeObjectURL(blobUrl);
      }
    } catch (e) {
      AppLogger.e('Failed to generate thumbnail from file', 
          category: LogCategory.media, error: e);
      return null;
    }
  }
}
