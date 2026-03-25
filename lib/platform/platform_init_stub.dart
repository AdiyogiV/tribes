import 'platform_interface.dart';
import 'platform_stub.dart';

/// Stub initialization - replaced by actual implementations via conditional imports
void initializePlatformServices() {
  PlatformServices.setInstance(StubPlatformServices());
}
