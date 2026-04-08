import 'package:flutter/material.dart';
import 'package:aurogram/utils/performance/image_optimizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';

/// A widget that displays a user avatar with fallback options
/// when the primary image is not available
class UserAvatar extends StatelessWidget {
  /// User identifier for generating consistent fallbacks
  final String? userId;

  /// Direct URL to the user's profile image
  final String? imageUrl;

  /// Size of the avatar (width and height)
  final double size;

  /// Border radius for the avatar
  final BorderRadius? borderRadius;

  /// Whether to show a border around the avatar
  final bool showBorder;

  /// Color of the border if shown
  final Color? borderColor;

  /// Initials to display when image is not available
  final String? nameInitials;

  /// Custom placeholder widget
  final Widget? placeholder;

  /// Custom error widget
  final Widget? errorWidget;

  /// Whether to enable loading image from Firestore by userId
  final bool loadFromFirestore;

  // Cache expiry duration for user data
  static const Duration _cacheExpiry = Duration(minutes: 30);

  // Cache category for user avatar data
  static const String _cacheCategory = 'user_avatars';

  // Reuse the same Future per userId so FutureBuilder doesn't restart on parent rebuilds
  static final Map<String, Future<Map<String, dynamic>?>> _futureCache = {};

  const UserAvatar({
    super.key,
    this.userId,
    this.imageUrl,
    this.size = 40.0,
    this.borderRadius,
    this.showBorder = false,
    this.borderColor,
    this.nameInitials,
    this.placeholder,
    this.errorWidget,
    this.loadFromFirestore = false,
  });

  @override
  Widget build(BuildContext context) {
    // If we should load from Firestore and have a userId but no imageUrl
    if (loadFromFirestore &&
        userId != null &&
        (imageUrl == null || imageUrl!.isEmpty)) {
      return _buildFirestoreAvatar(context);
    }

    final BorderRadius effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(size / 2);

    // Decide which fallback to use based on available data
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallbackAvatar(context, effectiveBorderRadius);
    }

    // Build the avatar with the network image
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        border: showBorder
            ? Border.all(
                color: borderColor ?? Theme.of(context).dividerColor,
                width: 1.0,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: ImageOptimizer.buildOptimizedImage(
          url: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          borderRadius: effectiveBorderRadius,
          placeholder: placeholder ?? _buildLoadingPlaceholder(context),
          errorWidget: errorWidget ??
              _buildInitialsAvatar(context, effectiveBorderRadius),
        ),
      ),
    );
  }

  /// Get user data from centralized CacheService or Firestore
  static Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final cacheKey = 'avatar_$userId';

    try {
      // Try to get from centralized cache first
      final cacheService = locator<CacheService>();
      final cached = await cacheService.get(cacheKey, category: _cacheCategory);

      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
    } catch (e) {
      // CacheService might not be initialized yet, continue to Firestore
      AppLogger.d('CacheService not available, fetching from Firestore',
          category: LogCategory.ui);
    }

    try {
      // Fetch from Firestore if not in cache
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (snapshot.exists) {
        final userData = snapshot.data();
        if (userData != null) {
          // Store in centralized cache with expiry (if registered)
          if (locator.isRegistered<CacheService>()) {
            try {
              final cacheService = locator<CacheService>();
              await cacheService.set(
                'avatar_$userId',
                userData,
                expiry: _cacheExpiry,
                category: _cacheCategory,
              );
            } catch (e) {
              AppLogger.w('Failed to cache user avatar data',
                  category: LogCategory.ui,
                  data: {'userId': userId, 'error': e.toString()});
            }
          }
          return userData;
        }
      }
      return null;
    } catch (e) {
      AppLogger.w(
        'Error fetching user data from Firestore',
        category: LogCategory.ui,
        data: {'userId': userId, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Build avatar that loads the image URL from Firestore
  Widget _buildFirestoreAvatar(BuildContext context) {
    final BorderRadius effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(size / 2);

    // Use a stable key that includes the userId
    final avatarKey =
        userId != null ? ValueKey('firestore_avatar_$userId') : null;

    // Reuse cached Future per userId so parent rebuilds don't restart FutureBuilder
    final future = userId != null
        ? (_futureCache[userId!] ??= _getUserData(userId!))
        : Future<Map<String, dynamic>?>.value(null);

    return FutureBuilder<Map<String, dynamic>?>(
      key: avatarKey,
      future: future,
      builder: (context, snapshot) {
        // While loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder(context);
        }

        // If error or no data
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildFallbackAvatar(context, effectiveBorderRadius);
        }

        // Get user data
        final userData = snapshot.data!;

        // Get display picture URL and name
        final pictureUrl = userData['displayPicture'] as String?;
        final name = userData['name'] as String?;
        final initials = name != null && name.isNotEmpty
            ? name.substring(0, 1).toUpperCase()
            : null;

        if (pictureUrl == null || pictureUrl.isEmpty) {
          return _buildInitialsAvatar(
            context,
            effectiveBorderRadius,
            initials: initials,
          );
        }

        // Build with loaded URL
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            border: showBorder
                ? Border.all(
                    color: borderColor ?? Theme.of(context).dividerColor,
                    width: 1.0,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: ImageOptimizer.buildOptimizedImage(
              url: pictureUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              borderRadius: effectiveBorderRadius,
              placeholder: placeholder ?? _buildLoadingPlaceholder(context),
              errorWidget: errorWidget ??
                  _buildInitialsAvatar(
                    context,
                    effectiveBorderRadius,
                    initials: initials,
                  ),
            ),
          ),
        );
      },
    );
  }

  /// Build a fallback avatar when no image URL is provided
  Widget _buildFallbackAvatar(BuildContext context, BorderRadius borderRadius) {
    // If we have initials, show an avatar with initials
    if (nameInitials != null && nameInitials!.isNotEmpty) {
      return _buildInitialsAvatar(context, borderRadius);
    }

    // Otherwise, show the default user icon
    return _buildDefaultAvatar(context, borderRadius);
  }

  /// Build an avatar with user initials
  Widget _buildInitialsAvatar(
    BuildContext context,
    BorderRadius borderRadius, {
    String? initials,
  }) {
    // Generate a predictable color from userId
    final Color backgroundColor = _getAvatarColor();
    final String displayInitials =
        initials ?? nameInitials ?? _getFirstLetter();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppTheme.primaryLightColor,
                width: 1.0,
              )
            : null,
      ),
      child: Center(
        child: Text(
          displayInitials.toUpperCase(),
          style: TextStyle(
            color: AppTheme.textDarkColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Build the default avatar with user icon
  Widget _buildDefaultAvatar(BuildContext context, BorderRadius borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getAvatarColor(),
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppTheme.primaryLightColor,
                width: 1.0,
              )
            : null,
      ),
      child: Icon(
        Icons.person,
        color: AppTheme.textDarkColor,
        size: size * 0.6,
      ),
    );
  }

  /// Build a loading placeholder with shimmer effect
  Widget _buildLoadingPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppTheme.darkPlaceholder : AppTheme.skeletonLightColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
        border: showBorder
            ? Border.all(
                color: borderColor ??
                    AppTheme.primaryLightColor.withValues(alpha: 0.3),
                width: 1.0,
              )
            : null,
      ),
    );
  }

  /// Get a color based on the user ID
  Color _getAvatarColor() {
    if (userId == null || userId!.isEmpty) {
      // Default color for unknown users
      return AppTheme.primaryColor;
    }

    // Generate a consistent color based on the user ID
    // This ensures the same user always gets the same color
    final List<Color> avatarColors = [
      AppTheme.primaryColor,
      AppTheme.primaryLightColor,
      AppTheme.accentColor,
      AppTheme.accentLightColor,
      AppTheme.pastelMint,
      AppTheme.pastelLavender,
      AppTheme.pastelPeach,
      AppTheme.pastelLilac,
    ];

    // Use a hash of the user ID to pick a color
    final int colorIndex = userId!.hashCode.abs() % avatarColors.length;
    return avatarColors[colorIndex];
  }

  /// Get the first letter of an imagined name from the user ID
  String _getFirstLetter() {
    if (userId == null || userId!.isEmpty) {
      return 'U';
    }

    // Try to extract a meaningful character from the user ID
    // Typically user IDs might have some pattern we can leverage
    // Or just return the first character if nothing else
    if (userId!.length > 1) {
      // Try to find a letter in the user ID
      for (int i = 0; i < userId!.length; i++) {
        if (userId![i].toUpperCase() != userId![i].toLowerCase()) {
          return userId![i].toUpperCase();
        }
      }
    }

    // Default to first character or 'U' if empty
    return userId!.isNotEmpty ? userId![0].toUpperCase() : 'U';
  }

  /// Factory method to create an avatar that loads directly from Firestore
  static UserAvatar fromUserId({
    required String userId,
    double size = 40.0,
    bool showBorder = false,
    Color? borderColor,
    BorderRadius? borderRadius,
    BoxFit fit = BoxFit.cover,
  }) {
    // Use specific key for the avatar based on userId to prevent unnecessary rebuilds
    return UserAvatar(
      key: ValueKey('avatar_${userId}_$size'),
      userId: userId,
      loadFromFirestore: true,
      size: size,
      showBorder: showBorder,
      borderColor: borderColor,
      borderRadius: borderRadius,
    );
  }

  /// Clear the user data cache for a specific user or all users
  /// Uses the centralized CacheService
  static Future<void> clearCache([String? specificUserId]) async {
    if (specificUserId != null) {
      _futureCache.remove(specificUserId);
    } else {
      _futureCache.clear();
    }
    try {
      final cacheService = locator<CacheService>();
      if (specificUserId != null) {
        await cacheService.remove('avatar_$specificUserId',
            category: _cacheCategory);
      } else {
        // Clear entire user_avatars category by clearing individual known keys
        // For full category clear, we'd need to expose that in CacheService
        AppLogger.d('User avatar cache clear requested',
            category: LogCategory.ui);
      }
    } catch (e) {
      AppLogger.w('Failed to clear user avatar cache',
          category: LogCategory.ui, data: {'error': e.toString()});
    }
  }
}
