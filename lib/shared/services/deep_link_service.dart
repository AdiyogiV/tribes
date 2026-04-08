import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:aurogram/core/config/api_endpoints.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/routing/dynamic_link_navigator.dart';

/// Service for handling deep links (Universal Links, App Links, Custom Schemes)
///
/// Handles URLs like:
/// - https://aurogram.in/u/{userId}     → User profile
/// - https://aurogram.in/cosmic/{userId} → Compatibility check
/// - https://aurogram.in/p/{postId}     → Post
/// - https://aurogram.in/s/{spaceId}    → Space invite
/// - aurogram://s/{spaceId}             → Space invite (custom scheme)
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  /// Pending deep link to process after login
  String? _pendingDeepLink;
  String? get pendingDeepLink => _pendingDeepLink;

  /// Dedupe: avoid processing the same URL twice in quick succession (e.g. initial + stream on web)
  String? _lastHandledUrl;
  static const _dedupeWindow = Duration(seconds: 2);
  DateTime? _lastHandledAt;

  /// Clear pending deep link after processing
  void clearPendingDeepLink() {
    _pendingDeepLink = null;
  }

  /// Initialize deep link handling
  Future<void> initialize() async {
    AppLogger.i('🔗 DeepLinkService: Initializing with app_links',
        category: LogCategory.general);

    _appLinks = AppLinks();

    // Check for initial link (app opened via deep link when cold started)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        AppLogger.i('🔗 Initial deep link from app_links: $initialUri',
            category: LogCategory.general);
        _handleDeepLink(initialUri.toString());
      } else if (kIsWeb) {
        // On web, also check Uri.base as a fallback
        // This handles direct browser navigation to deep link URLs
        _checkWebUrl();
        // Re-check after a delay so we catch the URL once the app/navigator is ready
        // (avoids landing on FTUE when the first check ran too early)
        Future.delayed(const Duration(milliseconds: 1500), () {
          _checkWebUrl();
        });
      }
    } catch (e) {
      AppLogger.e('🔗 Error getting initial link',
          category: LogCategory.general, error: e);
      // On web, try Uri.base as fallback even if app_links fails
      if (kIsWeb) {
        _checkWebUrl();
        Future.delayed(const Duration(milliseconds: 1500), () {
          _checkWebUrl();
        });
      }
    }

    // Listen for links while app is running (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        AppLogger.i('🔗 Received deep link (stream): $uri',
            category: LogCategory.general);
        _handleDeepLink(uri.toString());
      },
      onError: (err) {
        AppLogger.e('🔗 Error in link stream',
            category: LogCategory.general, error: err);
      },
    );

    AppLogger.i('🔗 DeepLinkService: Initialized',
        category: LogCategory.general);
  }

  /// Check web URL for deep link paths (fallback for web platform)
  void _checkWebUrl() {
    try {
      final baseUri = Uri.base;
      AppLogger.d('🔗 Web URL check - base: $baseUri, path: ${baseUri.path}',
          category: LogCategory.general);

      // Check if the URL has a deep link path
      if (baseUri.pathSegments.isNotEmpty) {
        final firstSegment = baseUri.pathSegments.first;
        // Check if it's one of our deep link types
        if (['s', 'u', 'p', 'cosmic'].contains(firstSegment)) {
          AppLogger.i('🔗 Found deep link in web URL: $baseUri',
              category: LogCategory.general);
          _handleDeepLink(baseUri.toString());
        }
      }
    } catch (e) {
      AppLogger.e('🔗 Error checking web URL',
          category: LogCategory.general, error: e);
    }
  }

  /// Parse and handle a deep link URL
  void _handleDeepLink(String url) {
    try {
      // Dedupe: skip if same URL was just processed (e.g. getInitialLink + stream on web)
      final now = DateTime.now();
      if (_lastHandledUrl == url &&
          _lastHandledAt != null &&
          now.difference(_lastHandledAt!) < _dedupeWindow) {
        AppLogger.d('🔗 Skipping duplicate deep link: $url',
            category: LogCategory.general);
        return;
      }
      _lastHandledUrl = url;
      _lastHandledAt = now;

      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      AppLogger.d(
          '🔗 Parsing deep link - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}, segments: $pathSegments',
          category: LogCategory.general);

      String? type;
      String? id;

      // Handle custom scheme (aurogram://type/id) vs https (https://domain/type/id)
      String? rawId;
      if (uri.scheme == 'aurogram') {
        // For aurogram://s/ID, host is 's' and pathSegments is ['ID']
        type = uri.host;
        rawId = pathSegments.isNotEmpty ? pathSegments[0] : null;
      } else {
        // For https://domain/s/ID, pathSegments is ['s', 'ID']
        if (pathSegments.isEmpty) {
          AppLogger.w('🔗 Deep link has no path segments',
              category: LogCategory.general);
          return;
        }
        type = pathSegments[0];
        rawId = pathSegments.length > 1 ? pathSegments[1] : null;
      }
      // Decode path segment (e.g. %20 -> space) and trim; for /s/ use first token to avoid trailing text
      id = rawId != null
          ? Uri.decodeComponent(rawId).trim().split(RegExp(r'\s+')).first
          : null;

      if (type.isEmpty) {
        AppLogger.w('🔗 Deep link missing type', category: LogCategory.general);
        return;
      }

      if (id == null || id.isEmpty) {
        AppLogger.w('🔗 Deep link missing ID for type: $type',
            category: LogCategory.general);
        return;
      }

      switch (type) {
        case 'u': // User profile
          AppLogger.i('🔗 Navigating to user profile: $id',
              category: LogCategory.general);
          DynamicLinkNavigator.navigateToUserProfile(id);
          break;

        case 'cosmic': // Compatibility check - navigate to user profile (shows compatibility)
          AppLogger.i('🔗 Navigating to compatibility with user: $id',
              category: LogCategory.general);
          DynamicLinkNavigator.navigateToUserProfile(id);
          break;

        case 'p': // Post
          AppLogger.i('🔗 Navigating to post: $id',
              category: LogCategory.general);
          DynamicLinkNavigator.navigateToPost(id);
          break;

        case 's': // Space or Secret message slug
          // Normalize slug: strip trailing whitespace/text (e.g. /s/2jx1u9du%20no -> 2jx1u9du)
          final slug = id.trim().split(RegExp(r'\s+')).first;
          if (slug.isEmpty) break;
          final inviterId = uri.queryParameters['inv'];
          _handleSpaceOrSecretMessage(slug, inviterId);
          break;

        default:
          AppLogger.w('🔗 Unknown deep link type: $type',
              category: LogCategory.general);
      }
    } catch (e) {
      AppLogger.e('🔗 Error parsing deep link: $url',
          category: LogCategory.general, error: e);
    }
  }

  /// Manually process a URL (called from other services if needed)
  void processUrl(String url) {
    _handleDeepLink(url);
  }

  /// Store a pending deep link (for processing after login)
  void storePendingLink(String url) {
    _pendingDeepLink = url;
    AppLogger.i('🔗 Stored pending deep link: $url',
        category: LogCategory.general);
  }

  /// Process pending deep link if any
  void processPendingLink() {
    if (_pendingDeepLink != null) {
      AppLogger.i('🔗 Processing pending deep link',
          category: LogCategory.general);
      _handleDeepLink(_pendingDeepLink!);
      _pendingDeepLink = null;
    }
  }

  /// Handle /s/{id} links. Navigate immediately to InviteLandingPage so the user
  /// never stays on FTUE; that page resolves space vs anonymous slug and shows
  /// the correct screen (or "gram no longer exists").
  void _handleSpaceOrSecretMessage(String id, String? inviterId) {
    AppLogger.i('🔗 Navigating to /s/ landing: $id, inviter: $inviterId',
        category: LogCategory.general);
    DynamicLinkNavigator.navigateToSpaceInvite(id, inviterId);
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}

/// Extension for building share URLs
extension ShareUrlBuilder on DeepLinkService {
  /// Base URL for share links
  static const String baseUrl = ApiEndpoints.appBaseUrl;

  /// Build a user profile share URL
  static String userProfileUrl(String userId) => '$baseUrl/u/$userId';

  /// Build a cosmic connection (compatibility) share URL
  static String cosmicUrl(String userId) => '$baseUrl/cosmic/$userId';

  /// Build a post share URL
  static String postUrl(String postId) => '$baseUrl/p/$postId';

  /// Build a space share URL
  static String spaceUrl(String spaceId) => '$baseUrl/s/$spaceId';
}
