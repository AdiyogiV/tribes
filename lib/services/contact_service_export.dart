/// Conditional export for ContactService
/// Uses real implementation on mobile, stub on web
export 'contact_service.dart'
    if (dart.library.html) 'contact_service_stub.dart';
