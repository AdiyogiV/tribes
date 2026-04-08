import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

// Conditional import for Platform (only available on mobile)
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';

/// Manages device identification and metadata for multi-device support
class DeviceManager {
  static const String _deviceIdKey = 'device_id';
  
  static String? _cachedDeviceId;
  static Timer? _heartbeatTimer;
  
  /// Get or create persistent device ID
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null || deviceId.isEmpty) {
      // Generate new device ID
      deviceId = '${_getPlatformPrefix()}_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomSuffix()}';
      await prefs.setString(_deviceIdKey, deviceId);
      
      AppLogger.i('Generated new device ID: $deviceId',
          category: LogCategory.general);
      
      // Store device metadata
      await _storeDeviceMetadata(deviceId);
    } else {
      _cachedDeviceId = deviceId;
      // Update metadata periodically
      await _updateDeviceMetadata(deviceId);
    }
    
    // Start heartbeat if not already running
    _startHeartbeat(deviceId);
    
    return deviceId;
  }
  
  static String _getPlatformPrefix() {
    if (kIsWeb) {
      return 'web';
    }
    // Only check Platform on mobile (not web)
    // Platform stub returns false for isIOS/isAndroid on web, so this is safe
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    }
    return 'unknown';
  }
  
  static String _generateRandomSuffix() {
    final random = Random();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }
  
  /// Store device metadata in Firestore
  static Future<void> _storeDeviceMetadata(String deviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppLogger.d('No user logged in, skipping device metadata storage',
          category: LogCategory.general);
      return;
    }
    
    try {
      final deviceRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId);
      
      final fcmToken = await _getCurrentFcmToken();
      
      await deviceRef.set({
        'deviceId': deviceId,
        'platform': _getPlatformPrefix(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken,
        'appVersion': await _getAppVersion(),
        'osVersion': await _getOSVersion(),
      }, SetOptions(merge: true));
      
      AppLogger.i('Stored device metadata for $deviceId',
          category: LogCategory.general);
      
    } catch (e) {
      AppLogger.e('Failed to store device metadata',
          category: LogCategory.general, error: e);
    }
  }
  
  /// Update device metadata (last active timestamp, FCM token)
  static Future<void> _updateDeviceMetadata(String deviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final deviceRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId);
      
      final fcmToken = await _getCurrentFcmToken();
      
      await deviceRef.update({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken,
      });
      
    } catch (e) {
      AppLogger.w('Failed to update device metadata',
          category: LogCategory.general);
    }
  }
  
  /// Update last active timestamp (heartbeat)
  static void _startHeartbeat(String deviceId) {
    _heartbeatTimer?.cancel();
    
    // Update immediately
    _updateLastActive(deviceId);
    
    // Then update every 5 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        timer.cancel();
        return;
      }
      
      await _updateLastActive(deviceId);
    });
  }
  
  static Future<void> _updateLastActive(String deviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.w('Heartbeat failed', category: LogCategory.general);
    }
  }
  
  /// Get current FCM token
  static Future<String?> _getCurrentFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }
  
  /// Get app version (placeholder - implement based on your versioning system)
  static Future<String> _getAppVersion() async {
    // TODO: Implement actual version retrieval
    return '1.0.0';
  }
  
  /// Get OS version (placeholder - implement based on platform)
  static Future<String> _getOSVersion() async {
    // TODO: Implement actual OS version retrieval
    if (kIsWeb) {
      return 'web';
    }
    // Only check Platform on mobile (not web)
    // Platform stub returns false for isIOS/isAndroid on web, so this is safe
    if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isAndroid) {
      return 'Android';
    }
    return 'unknown';
  }
  
  /// Clean up device on sign out
  static Future<void> cleanupOnSignOut() async {
    final deviceId = await getDeviceId();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .update({
        'signedOutAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      
      AppLogger.i('Device cleanup completed on sign out',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.w('Device cleanup failed',
          category: LogCategory.general);
    }
    
    // Stop heartbeat
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _cachedDeviceId = null;
  }
  
  /// Clear cached device ID (useful for testing)
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    _cachedDeviceId = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
