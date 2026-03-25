import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/pages/astrology/astrology_details_page.dart';
import 'package:aurogram/pages/astrology/astrology_setup_page.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Brown theme colors for astrology - uses AppTheme
class AstroTheme {
  static Color brownColor(bool isDark) => AppTheme.astroBrown(isDark);
  static Color brownLight(bool isDark) => AppTheme.astroBrownLight(isDark);
  static Color brownBackground(bool isDark) => AppTheme.astroBrownBackground(isDark);
}

class AstrologyBadge extends StatefulWidget {
  final String uid;
  final bool isOwnProfile;

  const AstrologyBadge({
    super.key,
    required this.uid,
    required this.isOwnProfile,
  });

  @override
  State<AstrologyBadge> createState() => _AstrologyBadgeState();
}

class _AstrologyBadgeState extends State<AstrologyBadge> {
  late final AstrologyService _astrologyService;
  late final Future<AstrologyProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _astrologyService = AstrologyService();
    _profileFuture = _astrologyService.getProfile(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AstrologyProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final profile = snapshot.data;

        if (profile == null ||
            !profile.isEnabled ||
            !profile.hasCalculatedData) {
          return widget.isOwnProfile
              ? _buildEnablePrompt(context)
              : const SizedBox.shrink();
        }

        // Basic signs always visible to others (details only accessible by owner)
        return _buildAstroBadge(context, profile);
      },
    );
  }

  Widget _buildAstroBadge(BuildContext context, AstrologyProfile profile) {
    final theme = Theme.of(context);
    final brownColor = AstroTheme.brownColor(theme.brightness == Brightness.dark);
    final isDark = theme.brightness == Brightness.dark;

    // Only allow navigation for own profile
    final canNavigate = widget.isOwnProfile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canNavigate ? () => _navigateToDetails(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: brownColor.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: brownColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: brownColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.stars_rounded,
                  color: brownColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stars',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.ascendant ?? '—'} • ${profile.moonSign ?? '—'} • ${profile.sunSign ?? '—'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: brownColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Only show arrow for own profile (indicates tappable)
              if (canNavigate)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnablePrompt(BuildContext context) {
    final theme = Theme.of(context);
    final brownColor = AstroTheme.brownColor(theme.brightness == Brightness.dark);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToSetup(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: brownColor.withOpacity(isDark ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: brownColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: brownColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  color: brownColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stars',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add astrology',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: brownColor,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => AstrologyDetailsPage(uid: widget.uid),
      ),
    );
  }

  void _navigateToSetup(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => const AstrologySetupPage(),
      ),
    );
  }
}
