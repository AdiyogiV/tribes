import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/shared/models/contact_match.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Service for syncing device contacts and finding which ones are on the app.
class ContactService {
  ContactService._();
  static final instance = ContactService._();

  final _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  // Cache version - bump this when normalization logic changes to invalidate old cache
  static const _cacheVersion = 4; // v4: Full 64-char SHA256 hash (was 16 chars)

  // Local storage keys
  static const _keyContactsOnApp = 'contacts_on_app';
  static const _keyContactsNotOnApp = 'contacts_not_on_app';
  static const _keySyncTime = 'contacts_sync_time';
  static const _keyHasPermission = 'contacts_has_permission';
  static const _keyCacheVersion = 'contacts_cache_version';

  // Cache
  ContactSyncResult? _cache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 30);
  bool _isInitialized = false;

  /// Initialize service and load persisted contacts
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadFromStorage();
      _isInitialized = true;
      
      if (_cache != null) {
        AppLogger.i('ContactService initialized - loaded ${_cache!.onApp.length} on app, ${_cache!.notOnApp.length} not on app from storage',
            category: LogCategory.general);
      } else {
        AppLogger.d('ContactService initialized - no cached contacts',
            category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.e('Error initializing ContactService',
          category: LogCategory.general, error: e);
    }
  }

  /// Load contacts from local storage
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache version - invalidate if old
      final savedVersion = prefs.getInt(_keyCacheVersion) ?? 0;
      if (savedVersion != _cacheVersion) {
        AppLogger.i('Contact cache version mismatch (saved: $savedVersion, current: $_cacheVersion) - clearing old cache',
            category: LogCategory.general);
        await _clearStorageOnly(prefs);
        return;
      }
      
      final syncTimeStr = prefs.getString(_keySyncTime);
      if (syncTimeStr == null) return; // No saved data
      
      final syncTime = DateTime.tryParse(syncTimeStr);
      if (syncTime == null) return;
      
      final onAppJson = prefs.getString(_keyContactsOnApp);
      final notOnAppJson = prefs.getString(_keyContactsNotOnApp);
      final hasPermission = prefs.getBool(_keyHasPermission) ?? true;
      
      final onApp = <ContactMatch>[];
      final notOnApp = <ContactMatch>[];
      
      if (onAppJson != null) {
        final List<dynamic> decoded = jsonDecode(onAppJson);
        for (final item in decoded) {
          onApp.add(ContactMatch(
            name: item['name'] as String,
            phoneNumber: item['phoneNumber'] as String? ?? '',
            phoneHash: item['phoneHash'] as String,
            userId: item['userId'] as String?,
          ));
        }
      }
      
      if (notOnAppJson != null) {
        final List<dynamic> decoded = jsonDecode(notOnAppJson);
        for (final item in decoded) {
          notOnApp.add(ContactMatch(
            name: item['name'] as String,
            phoneNumber: item['phoneNumber'] as String? ?? '',
            phoneHash: item['phoneHash'] as String,
          ));
        }
      }
      
      _cache = ContactSyncResult(
        onApp: onApp,
        notOnApp: notOnApp,
        hasPermission: hasPermission,
      );
      _cacheTime = syncTime;
      
      AppLogger.d('Loaded contacts from local storage',
          category: LogCategory.general,
          data: {'onApp': onApp.length, 'notOnApp': notOnApp.length, 'syncTime': syncTimeStr});
    } catch (e) {
      AppLogger.e('Error loading contacts from storage',
          category: LogCategory.general, error: e);
    }
  }

  /// Save contacts to local storage
  Future<void> _saveToStorage() async {
    if (_cache == null || _cacheTime == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Serialize contacts to JSON
      final onAppJson = jsonEncode(_cache!.onApp.map((c) => {
        'name': c.name,
        'phoneNumber': c.phoneNumber,
        'phoneHash': c.phoneHash,
        'userId': c.userId,
      }).toList());
      
      final notOnAppJson = jsonEncode(_cache!.notOnApp.map((c) => {
        'name': c.name,
        'phoneNumber': c.phoneNumber,
        'phoneHash': c.phoneHash,
      }).toList());
      
      await prefs.setInt(_keyCacheVersion, _cacheVersion);
      await prefs.setString(_keyContactsOnApp, onAppJson);
      await prefs.setString(_keyContactsNotOnApp, notOnAppJson);
      await prefs.setString(_keySyncTime, _cacheTime!.toIso8601String());
      await prefs.setBool(_keyHasPermission, _cache!.hasPermission);
      
      AppLogger.i('Saved contacts to local storage (v$_cacheVersion)',
          category: LogCategory.general,
          data: {'onApp': _cache!.onApp.length, 'notOnApp': _cache!.notOnApp.length});
    } catch (e) {
      AppLogger.e('Error saving contacts to storage',
          category: LogCategory.general, error: e);
    }
  }
  
  /// Clear storage only (without clearing memory cache)
  Future<void> _clearStorageOnly(SharedPreferences prefs) async {
    await prefs.remove(_keyCacheVersion);
    await prefs.remove(_keyContactsOnApp);
    await prefs.remove(_keyContactsNotOnApp);
    await prefs.remove(_keySyncTime);
    await prefs.remove(_keyHasPermission);
  }

  /// Check if we have contact permission
  Future<bool> hasPermission() async {
    return await FlutterContacts.requestPermission(readonly: true);
  }

  /// Request contact permission
  Future<bool> requestPermission() async {
    return await FlutterContacts.requestPermission(readonly: true);
  }

  /// Sync contacts with server using backend Cloud Function.
  /// Returns cached if fresh.
  Future<ContactSyncResult> sync({bool forceRefresh = false}) async {
    // Initialize from storage if not done
    if (!_isInitialized) {
      await initialize();
    }
    
    // Return cache if valid
    if (!forceRefresh && _cache != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cache!;
      }
    }

    // Check permission
    if (!await hasPermission()) {
      return ContactSyncResult.permissionDenied();
    }

    try {
      // Fetch device contacts
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      AppLogger.d('Fetched ${contacts.length} contacts from device',
          category: LogCategory.general);

      // Build contact list for backend: [{name, phone}, ...]
      final contactList = <Map<String, String>>[];
      final phoneToName = <String, String>{}; // For lookup after matching
      
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final rawPhone = phone.number.trim();
          if (rawPhone.isEmpty) continue;
          
          // Remove obviously invalid short numbers
          final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
          if (digitsOnly.length < 10) continue;
          
          contactList.add({
            'name': contact.displayName,
            'phone': rawPhone,
          });
          phoneToName[rawPhone] = contact.displayName;
        }
      }

      if (contactList.isEmpty) {
        _cache = ContactSyncResult.empty();
        _cacheTime = DateTime.now();
        return _cache!;
      }

      AppLogger.i('Sending ${contactList.length} contacts to backend for matching',
          category: LogCategory.general);

      // Call backend Cloud Function
      final callable = _functions.httpsCallable('matchContacts');
      final result = await callable.call({
        'contacts': contactList,
      });

      // Handle dynamic types from Firebase - convert to proper types
      final rawData = result.data;
      final data = rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{};
      final matches = (data['matches'] as List<dynamic>?) ?? [];
      final rawStats = data['stats'];
      final stats = rawStats is Map ? Map<String, dynamic>.from(rawStats) : null;
      final debugSamples = data['debugSamples'] as List<dynamic>?;

      AppLogger.i('Backend matching complete',
          category: LogCategory.general,
          data: {
            'matches': matches.length,
            'stats': stats,
          });

      // Log debug samples
      if (debugSamples != null) {
        for (final rawSample in debugSamples.take(3)) {
          final sample = rawSample is Map ? Map<String, dynamic>.from(rawSample) : <String, dynamic>{};
          AppLogger.d('📞 Backend sample: "${sample['name']}" → ${sample['phone']} → hashes: ${sample['hashes']}',
              category: LogCategory.general);
        }
      }

      // Build result lists with deduplication
      final onApp = <ContactMatch>[];
      final notOnApp = <ContactMatch>[];
      final matchedPhones = <String>{}; // Track matched phones
      final matchedUserIds = <String>{}; // Track matched user IDs to avoid duplicates

      // Process matches - deduplicate by userId
      for (final rawMatch in matches) {
        // Convert to proper Map type
        final match = rawMatch is Map ? Map<String, dynamic>.from(rawMatch) : <String, dynamic>{};
        final name = match['name']?.toString() ?? '';
        final phone = match['phone']?.toString() ?? '';
        final hash = match['hash']?.toString() ?? '';
        final userId = match['userId']?.toString();
        
        if (userId != null && userId.isNotEmpty && !matchedUserIds.contains(userId)) {
          matchedUserIds.add(userId);
          onApp.add(ContactMatch(
            name: name,
            phoneNumber: phone,
            phoneHash: hash,
            userId: userId,
          ));
          matchedPhones.add(phone);
        }
      }

      // Build "not on app" list from remaining contacts - deduplicate by name
      final addedNames = <String>{};
      for (final contact in contactList) {
        final phone = contact['phone']!;
        final name = contact['name']!;
        final nameLower = name.toLowerCase();
        
        // Skip if phone was matched or name already added
        if (!matchedPhones.contains(phone) && !addedNames.contains(nameLower)) {
          addedNames.add(nameLower);
          final normalized = _normalizePhone(phone);
          notOnApp.add(ContactMatch(
            name: name,
            phoneNumber: phone,
            phoneHash: normalized != null ? hashPhone(normalized) : '',
          ));
        }
      }

      // Sort alphabetically
      onApp.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notOnApp.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _cache = ContactSyncResult(onApp: onApp, notOnApp: notOnApp);
      _cacheTime = DateTime.now();
      
      // Persist to storage
      await _saveToStorage();

      AppLogger.i(
          'Contact sync complete: ${onApp.length} on app, ${notOnApp.length} not on app',
          category: LogCategory.general);

      return _cache!;
    } catch (e, stackTrace) {
      AppLogger.e('Error syncing contacts',
          category: LogCategory.general, error: e, stackTrace: stackTrace);
      
      // Fall back to cached data if available
      if (_cache != null) {
        AppLogger.w('Using cached contacts due to sync error',
            category: LogCategory.general);
        return _cache!;
      }
      
      return ContactSyncResult.withError('Failed to sync contacts');
    }
  }

  /// Remove a contact from the "on app" list (after sending Namaste)
  Future<void> removeFromOnApp(String phoneHash) async {
    if (_cache == null) return;

    final newOnApp = _cache!.onApp.where((c) => c.phoneHash != phoneHash).toList();
    _cache = ContactSyncResult(
      onApp: newOnApp,
      notOnApp: _cache!.notOnApp,
      hasPermission: _cache!.hasPermission,
    );
    await _saveToStorage();
  }

  /// Remove a contact from the "not on app" list (after inviting)
  Future<void> removeFromNotOnApp(String phoneHash) async {
    if (_cache == null) return;

    final newNotOnApp =
        _cache!.notOnApp.where((c) => c.phoneHash != phoneHash).toList();
    _cache = ContactSyncResult(
      onApp: _cache!.onApp,
      notOnApp: newNotOnApp,
      hasPermission: _cache!.hasPermission,
    );
    await _saveToStorage();
  }

  /// Clear cache (call on logout)
  Future<void> clearCache() async {
    _cache = null;
    _cacheTime = null;
    _isInitialized = false;
    
    // Clear from storage too
    try {
      final prefs = await SharedPreferences.getInstance();
      await _clearStorageOnly(prefs);
    } catch (e) {
      AppLogger.e('Error clearing contacts from storage',
          category: LogCategory.general, error: e);
    }
  }

  /// Get cached result (may be null)
  ContactSyncResult? get cachedResult => _cache;
  
  /// Get phone number for a userId (returns null if not in contacts)
  /// This only returns phone numbers for people in user's device contacts
  String? getPhoneForUser(String userId) {
    if (_cache == null) return null;
    
    // Check "on app" contacts first
    for (final contact in _cache!.onApp) {
      if (contact.userId == userId) {
        return contact.phoneNumber;
      }
    }
    return null;
  }
  
  /// Check if a user is in device contacts
  bool isInContacts(String userId) {
    if (_cache == null) return false;
    return _cache!.onApp.any((c) => c.userId == userId);
  }

  // --- Static helpers ---

  /// Normalize phone number for consistent hashing
  static String? _normalizePhone(String phone) {
    // Remove all non-digit except leading +
    var digits = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Must have at least 10 digits
    final digitCount = digits.replaceAll('+', '').length;
    if (digitCount < 10) return null;

    // Ensure country code
    if (!digits.startsWith('+')) {
      // Remove leading 0 if present (common in Indian local numbers)
      if (digits.startsWith('0')) {
        digits = digits.substring(1);
      }
      
      if (digits.length == 10) {
        // Assume India (+91) for 10-digit numbers
        digits = '+91$digits';
      } else if (digits.startsWith('91') && digits.length == 12) {
        digits = '+$digits';
      } else if (digits.length > 10) {
        // Assume it has country code, just add +
        digits = '+$digits';
      }
    }

    return digits;
  }

  /// Hash phone number for privacy (public for use in registration)
  /// Returns full 64-character SHA256 hash for collision resistance
  static String hashPhone(String phone) {
    final bytes = utf8.encode(phone);
    final digest = sha256.convert(bytes);
    return digest.toString(); // Full 64-char hash
  }

  /// Save phone index for current user (call during registration)
  static Future<void> savePhoneIndex(String phoneNumber, String userId) async {
    final normalized = _normalizePhone(phoneNumber);
    if (normalized == null) return;

    final hash = hashPhone(normalized);

    await FirebaseFirestore.instance.collection('phoneIndex').doc(hash).set({
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    AppLogger.d('Saved phone index for user',
        category: LogCategory.general, data: {'hash': hash});
  }
}


