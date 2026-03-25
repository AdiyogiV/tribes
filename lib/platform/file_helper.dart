/// Platform-agnostic file helpers
/// Uses conditional imports to provide type-safe file operations

export 'file_helper_stub.dart'
    if (dart.library.io) 'file_helper_mobile.dart';
