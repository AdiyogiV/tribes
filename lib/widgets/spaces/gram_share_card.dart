import 'dart:io';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// A beautiful shareable card for gram invites
/// Designed to be captured as an image for social sharing
class GramShareCard extends StatelessWidget {
  final String gramName;
  final String? description;
  final File? displayPicture;
  final String? displayPictureUrl;
  final int memberCount;
  final bool isPrivate;
  final String? inviterName;

  const GramShareCard({
    super.key,
    required this.gramName,
    this.description,
    this.displayPicture,
    this.displayPictureUrl,
    this.memberCount = 0,
    this.isPrivate = false,
    this.inviterName,
  });

  // Golden primary color for dark card background
  static const Color _primary = Color(0xFFD4A574);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(AppDimensions.paddingXxl),
      color: AppTheme.darkGradientDeep, // Dark background for outer padding
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkGradientBase,
              AppTheme.darkGradientMid,
              AppTheme.darkGradientDeep,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Invite badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(
                  color: _primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                inviterName != null
                    ? '$inviterName invited you!'
                    : "You're Invited!",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),

            // Gram image or placeholder
            _buildGramImage(),
            const SizedBox(height: AppDimensions.spacingLg),

            // Gram name
            Text(
              gramName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),

            // Description if available
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                description!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: AppDimensions.spacingXl),

            // Stats row
            _buildStatsRow(),

            const SizedBox(height: AppDimensions.spacingXxl),

            // App branding
            _buildBranding(),
          ],
        ),
      ),
    );
  }

  Widget _buildGramImage() {
    Widget imageContent;

    // On mobile, prefer File if available
    if (!kIsWeb && displayPicture != null) {
      imageContent = Image.file(
        displayPicture!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    } else if (displayPictureUrl != null && displayPictureUrl!.isNotEmpty) {
      // Use CachedNetworkImage for web or when no File is available
      imageContent = CachedNetworkImage(
        imageUrl: displayPictureUrl!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    } else {
      imageContent = _buildPlaceholder();
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: _primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: imageContent,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 100,
      height: 100,
      color: AppTheme.darkGradientBase,
      child: Center(
        child: Icon(
          Icons.people_rounded,
          size: 40,
          color: _primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Member count
          _buildStatItem(
            icon: Icons.people_rounded,
            value: memberCount > 0 ? '$memberCount' : '—',
            label: 'members',
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // Visibility
          _buildStatItem(
            icon: isPrivate ? Icons.lock_rounded : Icons.public_rounded,
            value: isPrivate ? 'Private' : 'Public',
            label: 'gram',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: _primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBranding() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: Image.asset(
            'assets/images/icon_transparent.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'Aurogram',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
