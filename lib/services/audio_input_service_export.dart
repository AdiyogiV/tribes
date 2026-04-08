/// Conditional export for AudioInputService
/// Uses real implementation on mobile, stub on web
library;

export 'audio_input_service.dart'
    if (dart.library.html) 'audio_input_service_stub.dart';
