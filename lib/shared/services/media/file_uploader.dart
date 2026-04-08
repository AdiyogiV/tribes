/// Cross-platform file uploader
/// Uses conditional exports to provide platform-specific implementation
library;

export 'file_uploader_stub.dart'
    if (dart.library.io) 'file_uploader_mobile.dart';
