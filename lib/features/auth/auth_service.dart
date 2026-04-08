import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/features/feed/domain/feed_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';

enum Status {
  Undetermined,
  Uninitialized,
  Authenticated,
  Authenticating,
  Unauthenticated
}

class AuthService extends ChangeNotifier {
  // Properties
  final FirebaseAuth _auth;
  User? _user;
  Status _status;
  String? userId = '';
  bool isUserNew = false;

  /// Initial tab index to navigate to after onboarding
  /// null means use default (HolyCow/index 2)
  int? initialTabIndex;

  // Stream subscription for proper resource management
  StreamSubscription<User?>? _authSubscription;

  // Guard to prevent duplicate checkRegistration calls
  bool _isCheckingRegistration = false;

  // Flag to allow deferring auth check until app is ready
  bool _initializationReady = false;

  // Pending auth state to process once initialization is ready
  User? _pendingAuthUser;

  // Constructor
  AuthService.instance()
      : _auth = FirebaseAuth.instance,
        _status = Status.Undetermined {
    // Store subscription for proper disposal
    _authSubscription =
        _auth.authStateChanges().listen(_handleAuthStateChanges);
    // Don't call _handleAuthStateChanges immediately - wait for markReady()
    // Just store the current user for when we're ready
    _pendingAuthUser = _auth.currentUser;
    AppLogger.d('AuthService: created, deferring auth check until ready', category: LogCategory.auth);
  }

  /// Mark the auth service as ready to process auth state changes.
  /// Should be called after Firestore and other dependencies are configured.
  void markReady() {
    if (_initializationReady) return;
    _initializationReady = true;
    AppLogger.d('AuthService: markReady called, processing pending auth state', category: LogCategory.auth);
    AppLogger.i('🔐 AuthService marked ready, processing pending auth',
        category: LogCategory.auth);
    // Now process the pending auth state
    _handleAuthStateChanges(_pendingAuthUser ?? _auth.currentUser);
  }

  // Getters
  Status get status => _status;
  User? get user => _user;

  /// Signs out the current user.
  Future<void> signOut() async {
    // Clear FCM token from Firestore BEFORE signing out
    // This prevents notifications from being sent to this device for this user
    await _clearFcmTokenOnSignOut();

    // Clear chat service cache before signing out to prevent permission errors
    SpaceChatService().clearConversationsCache();

    // Clear feed cache to prevent stale data on re-login
    await FeedService().clearCache();

    await _auth.signOut();
    _status = Status.Unauthenticated;
    _user = null;
    userId = '';
    notifyListeners();
  }

  /// Clears the current device's FCM token from the user's document on sign out.
  Future<void> _clearFcmTokenOnSignOut() async {
    final currentUserId = _user?.uid;
    if (currentUserId == null) return;

    try {
      final currentToken = await FirebaseMessaging.instance.getToken();
      if (currentToken == null) return;

      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(currentUserId);
      final snapshot = await userDoc.get();

      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      // Check if user has fcmTokens array (new multi-device format)
      if (data.containsKey('fcmTokens') && data['fcmTokens'] is List) {
        await userDoc.update({
          'fcmTokens': FieldValue.arrayRemove([currentToken]),
        });
      }

      // Also clear the legacy single token field if it matches
      if (data['fcmToken'] == currentToken) {
        await userDoc.update({
          'fcmToken': FieldValue.delete(),
        });
      }
    } catch (e) {
      // Don't let token clearing failures prevent sign out
      AppLogger.w('FCM token clear failed on sign out',
          category: LogCategory.messaging);
    }
  }

  /// Signs in using the provided [authCreds].
  Future<void> signIn(AuthCredential authCreds) async {
    _status = Status.Authenticating;
    notifyListeners();

    try {
      await _auth.signInWithCredential(authCreds);
      // Status will be updated by _handleAuthStateChanges listener
    } catch (e) {
      _status = Status.Unauthenticated;
      AppLogger.e('Sign in failed', category: LogCategory.auth, error: e);
      rethrow;
    }
  }

  /// Signs in using an OTP.
  Future<void> signInWithOTP(String smsCode, String verId) async {
    try {
      AuthCredential authCreds =
          PhoneAuthProvider.credential(verificationId: verId, smsCode: smsCode);
      await signIn(authCreds);
    } catch (e) {
      AppLogger.e('OTP sign in failed', category: LogCategory.auth, error: e);
      rethrow;
    }
  }

  /// Updates the status based on the [isUserNew] flag.
  /// Optionally set [initialTabIndex] to specify which tab to land on after auth.
  Future<void> updateStatusBasedOnNewUserFlag(bool isUserNew,
      {int? initialTabIndex}) async {
    final newStatus = isUserNew ? Status.Uninitialized : Status.Authenticated;
    AppLogger.i('Auth status changing', category: LogCategory.auth, data: {
      'from': _status.toString(),
      'to': newStatus.toString(),
      'isUserNew': isUserNew
    });
    _status = newStatus;
    this.isUserNew = isUserNew;
    this.initialTabIndex = initialTabIndex;
    notifyListeners();
  }

  /// Clears the initial tab index after it's been consumed by TabHandler
  void clearInitialTabIndex() {
    initialTabIndex = null;
  }

  // Private helper method to handle auth state changes
  Future<void> _handleAuthStateChanges(User? firebaseUser) async {
    AppLogger.d('AuthService: _handleAuthStateChanges called - hasUser: ${firebaseUser != null}, uid: ${firebaseUser?.uid}, status: $_status, ready: $_initializationReady', category: LogCategory.auth);

    // Store the user for later processing if not ready yet
    if (!_initializationReady) {
      AppLogger.d('AuthService: Not ready yet, storing pending user', category: LogCategory.auth);
      _pendingAuthUser = firebaseUser;
      // Set basic user info even if not ready, but don't check registration
      if (firebaseUser != null) {
        _user = firebaseUser;
        userId = firebaseUser.uid;
        if (_status == Status.Undetermined) {
          _status = Status.Authenticating;
          notifyListeners();
        }
      }
      return;
    }

    AppLogger.i('🔐 _handleAuthStateChanges called',
        category: LogCategory.auth,
        data: {
          'hasUser': firebaseUser != null,
          'uid': firebaseUser?.uid,
          'currentStatus': _status.toString()
        });

    // Track if we need to notify listeners (only when something actually changes)
    bool shouldNotify = false;

    if (firebaseUser == null) {
      AppLogger.i('🔐 No Firebase user, setting Unauthenticated',
          category: LogCategory.auth);
      if (_status != Status.Unauthenticated || _user != null) {
        _status = Status.Unauthenticated;
        _user = null;
        userId = '';
        shouldNotify = true;
        // Clear chat service cache when user logs out
        SpaceChatService().clearConversationsCache();
      }
    } else {
      // Check if user actually changed
      bool userChanged = _user?.uid != firebaseUser.uid;

      // Set user info immediately
      _user = firebaseUser;
      userId = _user?.uid;

      // Set status to Authenticating while checking registration
      if (_status == Status.Undetermined || _status == Status.Authenticating) {
        if (_status != Status.Authenticating) {
          _status = Status.Authenticating;
          shouldNotify = true;
          AppLogger.i('🔐 Status set to Authenticating',
              category: LogCategory.auth);
        }
      }

      // Prevent duplicate checkRegistration calls
      if (_isCheckingRegistration) {
        AppLogger.d('AuthService: Already checking registration, skipping', category: LogCategory.auth);
        AppLogger.i('🔐 Already checking registration, skipping',
            category: LogCategory.auth);
        if (userChanged && shouldNotify) {
          notifyListeners();
        }
        return;
      }

      // Only check registration if user changed or status needs updating
      AppLogger.d('AuthService: Checking condition - userChanged: $userChanged, status: $_status', category: LogCategory.auth);
      if (userChanged ||
          _status == Status.Undetermined ||
          _status == Status.Authenticating) {
        bool updateStatusCalled = false;
        try {
          _isCheckingRegistration = true;
          AppLogger.d('AuthService: Starting checkRegistration...', category: LogCategory.auth);
          AppLogger.i('🔐 Starting checkRegistration...',
              category: LogCategory.auth);

          // Add timeout to prevent infinite loading if Firestore call hangs
          // Reduced to 10s for faster failure - checkRegistration has 5s internal timeout
          AppLogger.d('AuthService: Calling checkRegistration with 10s outer timeout...', category: LogCategory.auth);
          isUserNew = await locator<UserService>().checkRegistration().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              AppLogger.w('AuthService: OUTER TIMEOUT - checkRegistration took too long (10s)', category: LogCategory.auth);
              AppLogger.w('🔐 Auth check timed out after 10s',
                  category: LogCategory.auth);
              throw TimeoutException('checkRegistration timed out');
            },
          );

          AppLogger.d('AuthService: checkRegistration returned - isUserNew: $isUserNew', category: LogCategory.auth);
          AppLogger.i('🔐 checkRegistration completed',
              category: LogCategory.auth, data: {'isUserNew': isUserNew});
          await updateStatusBasedOnNewUserFlag(isUserNew);
          AppLogger.d('AuthService: updateStatusBasedOnNewUserFlag completed', category: LogCategory.auth);
          updateStatusCalled = true;
        } catch (e, stackTrace) {
          AppLogger.e('AuthService: Auth state check FAILED with error: $e', category: LogCategory.auth);
          AppLogger.e('AuthService: stackTrace: $stackTrace', category: LogCategory.auth);
          AppLogger.e('🔐 Auth state check failed',
              category: LogCategory.auth, error: e);

          // Check if user was deleted
          if (e.toString().contains('deleted') ||
              e.toString().contains('Account has been deleted')) {
            AppLogger.w('AuthService: User is deleted, signing out', category: LogCategory.auth);
            AppLogger.w('🔐 User is deleted, signing out',
                category: LogCategory.auth);
            // Sign out deleted user - this will trigger _handleAuthStateChanges with null user
            await signOut();
            return; // Don't update status, let signOut handle it
          }

          // On other errors, assume existing user to prevent showing InitUser page
          isUserNew = false;
          AppLogger.d('AuthService: Setting isUserNew=false and calling updateStatusBasedOnNewUserFlag', category: LogCategory.auth);
          await updateStatusBasedOnNewUserFlag(isUserNew);
          updateStatusCalled = true;
        } finally {
          _isCheckingRegistration = false;
          AppLogger.d('AuthService: _isCheckingRegistration set to false', category: LogCategory.auth);
        }

        if (updateStatusCalled) {
          shouldNotify = false;
        }
      }
    }

    if (shouldNotify) {
      AppLogger.i('🔐 Notifying listeners', category: LogCategory.auth);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Cancel auth state subscription to prevent memory leaks
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }
}
