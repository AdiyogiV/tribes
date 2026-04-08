/// Platform-agnostic file image helper
/// Provides methods to load images from local files on mobile
/// Returns null on web where local file access is not available
library;

export 'file_image_helper_stub.dart'
    if (dart.library.io) 'file_image_helper_mobile.dart';
