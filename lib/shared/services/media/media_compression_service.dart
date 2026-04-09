import 'dart:async';
import 'dart:io';
import 'package:aurogram/shared/services/media/media_storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

export 'compression_queue_manager.dart';
export 'video_compression_pipeline.dart';
export 'media_compressor_utils.dart';

// Compression quality profiles
enum CompressionQuality {
  high, // Higher quality, larger file
  balanced, // Default option
  low // Lower quality, smaller file
}

// Video resolution options
enum VideoResolution {
  original, // Keep original resolution
  p720, // 720p
  p480, // 480p
  p360 // 360p - smallest file size
}

// Network requirements for upload
enum NetworkRequirement {
  wifiOnly, // Upload only on WiFi
  preferWifi, // Prefer WiFi but allow cellular with user permission
  any // Upload on any connection
}

// EVENT CLASSES for reactive architecture
class UploadProgressEvent {
  final String postId;
  final String status;
  final int progress;
  final String? phase;
  final DateTime timestamp;
  final String? error;

  UploadProgressEvent({
    required this.postId,
    required this.status,
    required this.progress,
    this.phase,
    required this.timestamp,
    this.error,
  });
}

class UploadCompletionEvent {
  final String postId;
  final bool success;
  final String? error;
  final DateTime timestamp;
  final Map<String, dynamic>? uploadData;

  UploadCompletionEvent({
    required this.postId,
    required this.success,
    this.error,
    required this.timestamp,
    this.uploadData,
  });
}

/// Service responsible for handling media compression operations
class MediaCompressionService {
  static const String COMPRESSION_QUEUE_KEY = 'compression_queue';
  static const String COMPRESSION_PROGRESS_KEY = 'compression_progress';
  static const int MAX_QUEUE_SIZE =
      15; // Increased from 7 to allow more queued videos
  static bool isProcessingQueue = false;
  static bool shouldProcessAgain = false;

  final FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;
  final PostDbService postDbService = PostDbService();
  final MediaStorageService storageService = MediaStorageService();

  // EVENT-DRIVEN ARCHITECTURE: Stream controllers for real-time updates
  final progressController = StreamController<UploadProgressEvent>.broadcast();
  final completionController =
      StreamController<UploadCompletionEvent>.broadcast();

  // Expose streams for reactive listening
  Stream<UploadProgressEvent> get progressStream => progressController.stream;
  Stream<UploadCompletionEvent> get completionStream =>
      completionController.stream;

  // Default quality settings
  static const int defaultImageQuality = 80;
  static const int defaultVideoQuality = 720;

  // Compression constants
  static const double minImageQuality = 50.0;
  static const double maxImageQuality = 95.0;

  // Cached temp directory to avoid repeated lookups
  Directory? tempDir;

  // Flag to enable adaptive compression based on network quality
  bool adaptiveCompressionEnabled = true;

  /// Enable/disable adaptive compression
  set adaptiveCompression(bool value) {
    adaptiveCompressionEnabled = value;
  }

  /// Dispose stream controllers to prevent memory leaks.
  void dispose() {
    progressController.close();
    completionController.close();
  }
}

/// Utility class for returning tuples.
class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;

  Tuple2(this.item1, this.item2);
}

/// Helper function to decode image dimensions in an isolate.
Tuple2<int, int>? decodeImageDimensions(Uint8List bytes) {
  try {
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage != null) {
      return Tuple2(decodedImage.width, decodedImage.height);
    }
  } catch (_) {
    // Return null if decoding fails
  }
  return null;
}
