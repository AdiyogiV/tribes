/// Stub implementation of permission_handler for web
/// Web handles permissions differently through browser APIs
/// 
/// IMPORTANT: On web, camera/microphone permissions are requested via
/// getUserMedia() which triggers the browser's permission prompt.
/// This stub exists for API compatibility but should not be relied upon
/// for actual permission checking on web. Use navigator.mediaDevices.getUserMedia()
/// directly for media permissions on web.
library;

enum PermissionStatus {
  denied,
  granted,
  restricted,
  limited,
  permanentlyDenied;
  
  /// Check if permission is denied
  bool get isDenied => this == PermissionStatus.denied || this == PermissionStatus.permanentlyDenied;
  
  /// Check if permission is granted
  bool get isGranted => this == PermissionStatus.granted || this == PermissionStatus.limited;
  
  /// Check if permission is restricted (iOS only concept)
  bool get isRestricted => this == PermissionStatus.restricted;
  
  /// Check if permission is limited (iOS 14+ limited photo access)
  bool get isLimited => this == PermissionStatus.limited;
  
  /// Check if permission is permanently denied
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
}

class Permission {
  static final Permission microphone = Permission._('microphone');
  static final Permission speech = Permission._('speech');
  static final Permission camera = Permission._('camera');
  static final Permission photos = Permission._('photos');
  static final Permission storage = Permission._('storage');
  static final Permission location = Permission._('location');
  static final Permission notification = Permission._('notification');

  final String _name;
  Permission._(this._name);

  /// Request permission on web
  /// Note: For camera/microphone on web, use navigator.mediaDevices.getUserMedia()
  /// which properly triggers the browser permission prompt.
  /// This stub returns 'denied' to indicate that explicit handling is needed.
  Future<PermissionStatus> request() async {
    // On web, media permissions are handled via getUserMedia()
    // Return 'denied' to force proper handling through browser APIs
    // For notification, the browser handles it differently
    if (_name == 'notification') {
      // Notification permissions can be checked via Notification API
      return PermissionStatus.granted; // Assume granted, actual check happens elsewhere
    }
    
    // For camera/microphone, we return denied to indicate
    // that the caller should use getUserMedia() directly
    if (_name == 'camera' || _name == 'microphone') {
      return PermissionStatus.denied;
    }
    
    // Other permissions are generally not available on web
    return PermissionStatus.denied;
  }

  /// Check permission status on web
  /// Note: Web doesn't have a reliable way to check media permissions
  /// without actually requesting them. Use with caution.
  Future<PermissionStatus> get status async {
    // For notification, we can check via the Notification API
    if (_name == 'notification') {
      return PermissionStatus.granted; // Simplified - actual check done elsewhere
    }
    
    // For camera/microphone, we can't check without prompting
    // Return denied to be safe
    if (_name == 'camera' || _name == 'microphone') {
      return PermissionStatus.denied;
    }
    
    return PermissionStatus.denied;
  }
  
  /// Check if permission is granted
  Future<bool> get isGranted async {
    final currentStatus = await status;
    return currentStatus == PermissionStatus.granted;
  }
  
  /// Check if permission is denied
  Future<bool> get isDenied async {
    final currentStatus = await status;
    return currentStatus == PermissionStatus.denied;
  }
}
