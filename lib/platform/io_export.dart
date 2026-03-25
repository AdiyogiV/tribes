/// Conditional export for dart:io
/// On web, exports a stub that provides placeholder types
/// On mobile, exports the real dart:io

export 'dart:io'
    if (dart.library.html) 'io_stub.dart';
