/// Cross-platform audio recorder
/// 
/// Uses conditional exports to provide platform-specific implementations:
/// - Web: Uses MediaRecorder API via dart:js_interop
/// - Mobile: Uses `record` package with AAC codec
/// - Other: Falls back to stub implementation
library;

export 'audio_recorder_stub.dart'
    if (dart.library.io) 'audio_recorder_mobile.dart'
    if (dart.library.html) 'audio_recorder_web.dart';

// Also export the interface for typing
export 'audio_recorder_interface.dart';
