import 'package:flutter/material.dart';
import 'package:aurogram/core/storage/image_optimizer.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/services/cache_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/astrology/data/utils/yoni_tribe.dart';

/// A widget that displays a user avatar with fallback options
/// when the primary image is not available
class UserAvatar extends StatelessWidget {
  // Slightly reduce saturation for yoni artwork so it reads better at tiny
  // avatar sizes (e.g., 40-56px circles) without regenerating image assets.
  static const double _tribeSaturation = 0.9;

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

  /// The user's (Moon/Janma) nakshatra name. When provided and no profile
  /// picture is available, the avatar falls back to the user's yoni tribe
  /// image instead of plain initials. Spelling variants are handled via
  /// [YoniTribeData.forNakshatraName].
  final String? nakshatra;

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
    this.nakshatra,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(size / 2);

    // 1. An explicit image URL always wins.
    if (imageUrl != null && imageUrl!.isNotEmpty) {
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

    // 2. No explicit image but we know who this is: look the user up so we can
    // render their stored picture or, failing that, their yoni-tribe default.
    // This makes the tribe avatar the automatic default everywhere a userId is
    // available — no per-call-site wiring needed.
    if (userId != null && userId!.isNotEmpty) {
      return _buildFirestoreAvatar(context);
    }

    // 3. Nothing to look up — static fallback (tribe if a nakshatra was passed
    // directly, otherwise initials / default icon).
    return _buildFallbackAvatar(context, effectiveBorderRadius);
  }

  /// Extract a nakshatra name from a `users/{uid}` document map.
  ///
  /// Nakshatra is stored in nested maps, not at the top level:
  ///   - `astrology.nakshatra`           — public, display-safe mirror
  ///   - `astrologyData.moonNakshatra`   — authoritative private profile
  ///   - `astrologyData.nakshatra`       — backward-compat alias
  /// Returns null when the user has no computed astrology data.
  static String? _nakshatraFromUserData(Map<String, dynamic> userData) {
    String? pick(dynamic map, List<String> keys) {
      if (map is Map) {
        for (final key in keys) {
          final value = map[key];
          if (value is String && value.trim().isNotEmpty) return value;
        }
      }
      return null;
    }

    return pick(userData['astrology'], const ['nakshatra']) ??
        pick(userData['astrologyData'],
            const ['moonNakshatra', 'nakshatra']) ??
        pick(userData, const ['nakshatra', 'moonNakshatra']);
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
      final snapshot = await locator<UserRepository>().getUser(userId);

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
        // While loading: if the caller already gave us a nakshatra or initials,
        // show that immediately (avoids a blank-box flash in lists). Otherwise
        // show the shimmer placeholder until the user doc resolves.
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (nakshatra != null) {
            final tribe = _buildTribeAvatar(context, effectiveBorderRadius);
            if (tribe != null) return tribe;
          }
          if (nameInitials != null && nameInitials!.isNotEmpty) {
            return _buildInitialsAvatar(context, effectiveBorderRadius);
          }
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
          // Fall back to the yoni tribe image, using the nakshatra passed in or
          // one stored on the user document.
          final userNakshatra = nakshatra ?? _nakshatraFromUserData(userData);
          final tribe = _buildTribeAvatar(
            context,
            effectiveBorderRadius,
            nakshatra: userNakshatra,
            initials: initials,
          );
          if (tribe != null) return tribe;

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
    // Prefer the user's yoni tribe image when their nakshatra is known.
    final tribe = _buildTribeAvatar(context, borderRadius);
    if (tribe != null) return tribe;

    // If we have initials, show an avatar with initials
    if (nameInitials != null && nameInitials!.isNotEmpty) {
      return _buildInitialsAvatar(context, borderRadius);
    }

    // Otherwise, show the default user icon
    return _buildDefaultAvatar(context, borderRadius);
  }

  /// Build a yoni-tribe avatar from a nakshatra, or return null when the
  /// nakshatra is unknown so callers can fall through to initials/default.
  /// The image is served publicly from Firebase Storage (`/yoni_tribes/`).
  Widget? _buildTribeAvatar(
    BuildContext context,
    BorderRadius borderRadius, {
    String? nakshatra,
    String? initials,
  }) {
    final tribe = YoniTribeData.forNakshatraName(nakshatra ?? this.nakshatra);
    if (tribe == null) return null;

    final image = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: borderColor ?? Theme.of(context).dividerColor,
                width: 1.0,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ImageOptimizer.buildOptimizedImage(
          url: tribe.imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          borderRadius: borderRadius,
          placeholder: placeholder ?? _buildLoadingPlaceholder(context),
          errorWidget: _buildInitialsAvatar(
            context,
            borderRadius,
            initials: initials,
          ),
        ),
      ),
    );

    if (_tribeSaturation >= 0.999) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_saturationMatrix(_tribeSaturation)),
      child: image,
    );
  }

  static List<double> _saturationMatrix(double s) {
    const rw = 0.2126;
    const gw = 0.7152;
    const bw = 0.0722;
    final a = (1 - s) * rw + s;
    final b = (1 - s) * rw;
    final c = (1 - s) * rw;
    final d = (1 - s) * gw;
    final e = (1 - s) * gw + s;
    final f = (1 - s) * gw;
    final g = (1 - s) * bw;
    final h = (1 - s) * bw;
    final i = (1 - s) * bw + s;
    return <double>[
      a, d, g, 0, 0,
      b, e, h, 0, 0,
      c, f, i, 0, 0,
      0, 0, 0, 1, 0,
    ];
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
    String? nakshatra,
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
      nakshatra: nakshatra,
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
