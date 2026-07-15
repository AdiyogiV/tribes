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

  /// True while the user is a silent Firebase *anonymous* guest (value-first
  /// onboarding). They can talk to Baba, get a reading, and have data saved
  /// under their anon uid — but they are NOT a registered account yet. When
  /// they choose to save, we LINK this anon account to a phone credential so
  /// the uid (and all their data) carries over. Gating keys off this, not
  /// [status], so a guest lands on the value-first tabs, never InitUser.
  bool get isGuest => _user?.isAnonymous ?? false;

  /// True only for a FULLY REGISTERED account (authenticated AND not an
  /// anonymous guest). Use this to gate actions that need a real account
  /// (posting, liking, following, account settings). A guest failing this
  /// check should be shown the login/link prompt — which upgrades their anon
  /// account in place, so nothing they did as a guest is lost.
  bool get isRegistered => _status == Status.Authenticated && !isGuest;


  /// Initial tab index to navigate to after onboarding
  /// null means use default (Baba/index 2)
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

  /// Ensures there is ALWAYS a Firebase identity by silently signing the user
  /// in anonymously when none exists. This is what removes the login wall:
  /// a fresh visitor gets a real uid + verifiable ID token (so Baba's voice
  /// relay works) without ever seeing a login screen. Idempotent.
  Future<void> signInAnonymouslyIfNeeded() async {
    if (_auth.currentUser != null) return;
    try {
      AppLogger.i(' No user — signing in anonymously (guest)',
          category: LogCategory.auth);
      await _auth.signInAnonymously();
      // _handleAuthStateChanges fires with the new anon user and takes over.
    } catch (e) {
      AppLogger.e('Anonymous sign-in failed',
          category: LogCategory.auth, error: e);
      // Leave status as-is; the app can retry on next resume.
    }
  }

  /// Signs in using the provided [authCreds].
  ///
  /// If the current user is an anonymous GUEST, we LINK the credential to that
  /// account so their uid (and everything saved under it — name, birth
  /// details, reading) carries over seamlessly. If that phone already belongs
  /// to an existing account, we fall back to signing into THAT account (the
  /// guest's throwaway data is abandoned, which is the correct behaviour — the
  /// returning user wants their real account).
  Future<void> signIn(AuthCredential authCreds) async {
    _status = Status.Authenticating;
    notifyListeners();

    try {
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        try {
          AppLogger.i(' Linking phone credential to anonymous guest',
              category: LogCategory.auth, data: {'uid': current.uid});
          await current.linkWithCredential(authCreds);
          // Linked: same uid, data preserved. Listener updates status.
          return;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'account-exists-with-different-credential') {
            AppLogger.w(
                ' Phone already registered — signing into existing account',
                category: LogCategory.auth, data: {'code': e.code});
            // Prefer the credential returned by the exception (it is the
            // resolved, usable one); fall back to what we were given.
            await _auth.signInWithCredential(e.credential ?? authCreds);
            return;
          }
          rethrow;
        }
      }
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
      // No Firebase identity => silently become an anonymous GUEST so the app
      // is always value-first (no login wall) and Baba's relay has a token.
      // Sign-out therefore simply drops you back to guest mode, never a dead
      // signed-out screen. 'Registering' = linking this anon uid to a phone.
      AppLogger.i(' No Firebase user, provisioning anonymous guest',
          category: LogCategory.auth);
      if (_user != null) {
        // Was registered, now signed out: clear registered caches.
        SpaceChatService().clearConversationsCache();
      }
      if (_status != Status.Authenticating) {
        _status = Status.Authenticating;
        notifyListeners();
      }
      // Re-enters this handler with the new anon user (branch below).
      unawaited(signInAnonymouslyIfNeeded());
      return;
    } else if (firebaseUser.isAnonymous) {
      // Anonymous GUEST: no registration doc needed. Skip the whole
      // checkRegistration/InitUser path and treat them as authenticated so
      // they land on the value-first tabs (Dashboard/Baba). Gating uses
      // [isGuest] to keep them out of registered-only surfaces.
      final userChanged = _user?.uid != firebaseUser.uid;
      _user = firebaseUser;
      userId = firebaseUser.uid;
      if (_status != Status.Authenticated || userChanged) {
        AppLogger.i(' Anonymous guest ready, status Authenticated (guest)',
            category: LogCategory.auth, data: {'uid': firebaseUser.uid});
        isUserNew = false;
        _status = Status.Authenticated;
        shouldNotify = true;
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
