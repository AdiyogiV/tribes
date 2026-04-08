import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/features/astrology/domain/compatibility_service.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/astrology/presentation/pages/compatibility_details_page.dart';

/// Follow relationship state for contextual messaging
enum FollowRelationship {
  none, // Neither follows
  requested, // You requested to follow (pending approval for private profile)
  youFollowThem, // You follow them (confirmed), waiting for follow back
  theyFollowYou, // They follow you, you should follow back
  mutual, // Both follow each other (friends)
}

/// Compatibility badge card - shows percentage score on other users' profiles
/// Only visible when users are mutual follows (friends)
/// Shows contextual unlock CTA when not friends
class CompatibilityBadge extends StatefulWidget {
  final String otherUserId;

  /// Optional: Pass follow state from parent to avoid extra network calls
  /// followStatus: null (not following), 'pending', or 'following'
  final String? followStatus;
  final bool? theyFollowYou;

  /// Callback when compatibility is unlocked (for parent to trigger share prompt)
  final VoidCallback? onUnlocked;

  /// User info for sharing - pass from parent if available
  final String? currentUserName;
  final String? otherUserName;
  final String? currentUserPhotoUrl;
  final String? otherUserPhotoUrl;

  /// Sign data for sharing
  final String? currentUserSun;
  final String? currentUserMoon;
  final String? currentUserRising;
  final String? otherUserSun;
  final String? otherUserMoon;
  final String? otherUserRising;

  const CompatibilityBadge({
    super.key,
    required this.otherUserId,
    this.followStatus,
    this.theyFollowYou,
    this.onUnlocked,
    this.currentUserName,
    this.otherUserName,
    this.currentUserPhotoUrl,
    this.otherUserPhotoUrl,
    this.currentUserSun,
    this.currentUserMoon,
    this.currentUserRising,
    this.otherUserSun,
    this.otherUserMoon,
    this.otherUserRising,
  });

  @override
  State<CompatibilityBadge> createState() => _CompatibilityBadgeState();
}

class _CompatibilityBadgeState extends State<CompatibilityBadge> {
  final CompatibilityService _compatibilityService = CompatibilityService();
  final FollowService _followService = FollowService();
  CompatibilityResult? _result;
  bool _isLoading = true;
  bool _isNotFriends = false;
  FollowRelationship _relationship = FollowRelationship.none;

  @override
  void initState() {
    super.initState();
    _loadCompatibility();
  }

  @override
  void didUpdateWidget(covariant CompatibilityBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if the target user changed
    if (oldWidget.otherUserId != widget.otherUserId) {
      _loadCompatibility();
    }
  }

  Future<void> _loadCompatibility() async {
    AppLogger.i(
        '💑 CompatibilityBadge: Loading for ${widget.otherUserId}, props: followStatus=${widget.followStatus}, theyFollowYou=${widget.theyFollowYou}',
        category: LogCategory.general);

    // Always determine actual follow relationship (don't trust possibly stale props)
    final relationship = await _determineFollowRelationship();
    final isMutual = relationship == FollowRelationship.mutual;

    AppLogger.i(
        '💑 CompatibilityBadge: Relationship=$relationship, isMutual=$isMutual',
        category: LogCategory.general);

    if (!isMutual) {
      // Not mutual followers - show locked state
      if (mounted) {
        setState(() {
          _result = null;
          _isNotFriends = true;
          _relationship = relationship;
          _isLoading = false;
        });
      }
      return;
    }

    // They are mutual followers, proceed with compatibility calculation
    setState(() {
      _isLoading = true;
      _isNotFriends = false;
    });

    try {
      final result =
          await _compatibilityService.getFullCompatibility(widget.otherUserId);
      AppLogger.i(
          '💑 CompatibilityBadge: Received result: cosmic=${result?.cosmicMatch?.score ?? 'null'}%, traditional=${result?.traditionalMatch?.totalScore ?? 'null'}',
          category: LogCategory.general);

      // Determine follow relationship for contextual messaging
      FollowRelationship relationship = FollowRelationship.none;
      if (result != null) {
        relationship = FollowRelationship.mutual;
      } else if (_compatibilityService.isNotFriendsError) {
        relationship = await _determineFollowRelationship();
      }

      if (mounted) {
        setState(() {
          _result = result;
          _isNotFriends = _compatibilityService.isNotFriendsError;
          _relationship = relationship;
          _isLoading = false;
        });

        // Notify parent if compatibility was just unlocked
        if (result != null && widget.onUnlocked != null) {
          widget.onUnlocked!();
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e('💑 Error loading compatibility in widget',
          category: LogCategory.general, error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isNotFriends = _compatibilityService.isNotFriendsError;
        });
      }
    }
  }

  /// Determine follow relationship for contextual unlock message
  /// Always fetches fresh data to ensure accuracy
  Future<FollowRelationship> _determineFollowRelationship() async {
    // Always fetch fresh data - props may be stale on initial render
    final results = await Future.wait([
      _followService.getFollowStatus(widget.otherUserId),
      _followService.isFollowedBy(widget.otherUserId),
    ]);

    final yourStatus = results[0] as String?;
    final theyFollow = results[1] as bool;

    final youFollowConfirmed = yourStatus == FollowService.statusFollowing;
    final youRequested = yourStatus == FollowService.statusPending;

    AppLogger.i(
        '💑 _determineFollowRelationship: yourStatus=$yourStatus, theyFollow=$theyFollow',
        category: LogCategory.general);

    if (youFollowConfirmed && theyFollow) {
      return FollowRelationship.mutual;
    } else if (youRequested) {
      return FollowRelationship.requested;
    } else if (youFollowConfirmed) {
      return FollowRelationship.youFollowThem;
    } else if (theyFollow) {
      return FollowRelationship.theyFollowYou;
    }
    return FollowRelationship.none;
  }

  /// Reload compatibility (call from parent after follow action)
  void reload() {
    _loadCompatibility();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while calculating
    if (_isLoading) {
      return TransparentToolbox.buildCard(
        context: context,
        child: _buildLoadingContent(),
      );
    }

    // Show "unlock" state for non-friends (mutual follow required)
    if (_isNotFriends) {
      return TransparentToolbox.buildCard(
        context: context,
        child: _buildUnlockContent(),
      );
    }

    // Show error message if available, otherwise hide
    if (_result == null) {
      final errorMsg = _compatibilityService.errorMessage;
      if (errorMsg != null) {
        return TransparentToolbox.buildCard(
          context: context,
          child: _buildErrorContent(errorMsg),
        );
      }
      return const SizedBox.shrink();
    }

    // Tappable card - navigates to compatibility details
    return TransparentToolbox.buildCard(
      context: context,
      onTap: () => _navigateToDetails(),
      child: _buildScoreContent(),
    );
  }

  void _navigateToDetails() {
    if (_result == null) return;

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => CompatibilityDetailsPage(
          result: _result!,
          otherUserId: widget.otherUserId,
          currentUserName: widget.currentUserName ?? 'Me',
          otherUserName: widget.otherUserName ?? 'Friend',
          currentUserPhotoUrl: widget.currentUserPhotoUrl,
          otherUserPhotoUrl: widget.otherUserPhotoUrl,
          currentUserSun: widget.currentUserSun,
          currentUserMoon: widget.currentUserMoon,
          currentUserRising: widget.currentUserRising,
          otherUserSun: widget.otherUserSun,
          otherUserMoon: widget.otherUserMoon,
          otherUserRising: widget.otherUserRising,
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    final c = AppTheme.primaryColor;

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'COMPATIBILITY',
                  style: AppTheme.cardLabelStyle,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  'Calculating...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          InlineShimmerLoader(size: 16, color: c),
        ],
      ),
    );
  }

  Widget _buildErrorContent(String errorMsg) {
    final c = AppTheme.primaryColor;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'COMPATIBILITY',
            style: AppTheme.cardLabelStyle,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            errorMsg,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.withValues(alpha: 0.6),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the "unlock" content for non-friends with contextual message
  Widget _buildUnlockContent() {
    final c = AppTheme.primaryColor;

    // Contextual message based on follow relationship
    String message;
    IconData icon;
    Color iconColor;

    switch (_relationship) {
      case FollowRelationship.theyFollowYou:
        // They follow you - prompt to follow back (most actionable!)
        message = 'Follow back to unlock';
        icon = CupertinoIcons.arrow_turn_down_left;
        iconColor = AppTheme.honeyAmber;
        break;
      case FollowRelationship.requested:
        // Pending follow request (waiting for private profile to approve)
        message = 'Request pending';
        icon = CupertinoIcons.hourglass;
        iconColor = c.withValues(alpha: 0.5);
        break;
      case FollowRelationship.youFollowThem:
        // You follow them (confirmed) - waiting for them to follow back
        message = 'Waiting for follow back';
        icon = CupertinoIcons.clock_fill;
        iconColor = c.withValues(alpha: 0.5);
        break;
      case FollowRelationship.none:
      case FollowRelationship.mutual:
        // Generic message
        message = 'Follow each other to unlock';
        icon = CupertinoIcons.lock_fill;
        iconColor = c.withValues(alpha: 0.5);
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'COMPATIBILITY',
            style: AppTheme.cardLabelStyle,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmMd),
              Icon(
                icon,
                size: 14,
                color: iconColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreContent() {
    if (_result == null) return const SizedBox.shrink();

    final c = AppTheme.primaryColor;

    // Use cosmic match score if available, otherwise traditional
    final score = _result!.primaryScore;
    final label = _result!.primaryLabel;
    final hasCosmic = _result!.cosmicMatch != null;

    // Display with chevron to indicate tappable
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasCosmic ? 'COSMIC MATCH' : 'COMPATIBILITY',
                  style: AppTheme.cardLabelStyle,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Row(
                  children: [
                    Text(
                      '$score%',
                      style: AppTheme.cardValueStyle,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: c.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
