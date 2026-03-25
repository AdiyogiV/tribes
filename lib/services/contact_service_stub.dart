/// Stub for ContactService on web
/// Contact sync is not supported on web browsers

/// Result of contact sync operation
class ContactSyncResult {
  final List<ContactMatch> onApp;
  final List<ContactMatch> notOnApp;
  final bool hasPermission;
  final String? error;

  ContactSyncResult({
    this.onApp = const [],
    this.notOnApp = const [],
    this.hasPermission = false,
    this.error,
  });

  factory ContactSyncResult.permissionDenied() {
    return ContactSyncResult(hasPermission: false);
  }

  factory ContactSyncResult.empty() {
    return ContactSyncResult(hasPermission: true);
  }

  factory ContactSyncResult.withError(String error) {
    return ContactSyncResult(error: error);
  }
}

/// Contact match info
class ContactMatch {
  final String name;
  final String phoneNumber;
  final String phoneHash;
  final String? userId;

  ContactMatch({
    required this.name,
    required this.phoneNumber,
    required this.phoneHash,
    this.userId,
  });
}

/// Stub ContactService for web - contact features disabled
class ContactService {
  ContactService._();
  static final instance = ContactService._();

  ContactSyncResult? _cache;

  /// Initialize - no-op on web
  Future<void> initialize() async {
    // Contact sync not available on web
  }

  /// Check permission - always false on web
  Future<bool> hasPermission() async {
    return false;
  }

  /// Request permission - always false on web
  Future<bool> requestPermission() async {
    return false;
  }

  /// Sync contacts - returns empty result on web
  Future<ContactSyncResult> sync({bool forceRefresh = false}) async {
    return ContactSyncResult(
      hasPermission: false,
      error: 'Contact sync is not available on web',
    );
  }

  /// Remove from on app list - no-op on web
  Future<void> removeFromOnApp(String phoneHash) async {}

  /// Remove from not on app list - no-op on web
  Future<void> removeFromNotOnApp(String phoneHash) async {}

  /// Clear cache - no-op on web
  Future<void> clearCache() async {
    _cache = null;
  }

  /// Get cached result
  ContactSyncResult? get cachedResult => _cache;

  /// Get phone for user - always null on web
  String? getPhoneForUser(String userId) => null;

  /// Check if user is in contacts - always false on web
  bool isInContacts(String userId) => false;

  /// Hash phone number (static helper)
  static String hashPhone(String phone) {
    // Simple hash for compatibility - actual implementation uses crypto
    return phone.hashCode.abs().toRadixString(16).substring(0, 16);
  }

  /// Save phone index - no-op on web
  static Future<void> savePhoneIndex(String phoneNumber, String userId) async {
    // Not available on web
  }
}
