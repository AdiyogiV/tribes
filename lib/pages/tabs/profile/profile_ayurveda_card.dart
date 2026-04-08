import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/pages/ayurveda/widgets/ayurveda_profile_card.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Ayurveda card showing constitution data or a setup prompt.
/// Only visible when astrology profile is set up.
class ProfileAyurvedaCard extends StatelessWidget {
  final bool isDark;
  final String uid;
  final Future<AstrologyProfile?>? astrologyProfileFuture;
  final Stream<AyurvedaProfile?>? ayurvedaProfileStream;
  final AyurvedaProfile? cachedAyurvedaProfile;
  final ValueChanged<AyurvedaProfile?> onAyurvedaProfileChanged;
  final VoidCallback onOpenDetails;

  const ProfileAyurvedaCard({
    super.key,
    required this.isDark,
    required this.uid,
    required this.astrologyProfileFuture,
    required this.ayurvedaProfileStream,
    required this.cachedAyurvedaProfile,
    required this.onAyurvedaProfileChanged,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AstrologyProfile?>(
      future: astrologyProfileFuture,
      builder: (context, astroSnapshot) {
        final astroProfile = astroSnapshot.data;
        final hasAstrology = astroProfile != null &&
            astroProfile.isEnabled &&
            astroProfile.hasCalculatedData;

        // Only show if astrology is set up
        if (!hasAstrology) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<AyurvedaProfile?>(
          stream: ayurvedaProfileStream,
          builder: (context, ayurSnapshot) {
            final ayurProfile = ayurSnapshot.data ?? cachedAyurvedaProfile;
            // Notify parent of profile changes for caching
            if (ayurSnapshot.data != null && ayurSnapshot.data != cachedAyurvedaProfile) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onAyurvedaProfileChanged(ayurSnapshot.data);
              });
            }
            final hasAyurveda = ayurProfile != null && ayurProfile.hasData;
            final isLoading =
                ayurSnapshot.connectionState == ConnectionState.waiting &&
                    ayurProfile == null;

            if (isLoading) {
              return _buildAyurvedaLoadingSkeleton(context, isDark);
            }

            if (hasAyurveda) {
              // Show the Ayurveda profile card
              return AyurvedaProfileCard(
                profile: ayurProfile,
                onTap: onOpenDetails,
              );
            } else {
              // Show setup card
              return _buildAyurvedaSetupCard(context, isDark);
            }
          },
        );
      },
    );
  }

  Widget _buildAyurvedaLoadingSkeleton(BuildContext context, bool isDark) {
    final skeletonBase = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.green.withValues(alpha: 0.1);
    return TransparentToolbox.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AYURVEDA', style: AppTheme.cardLabelStyle),
          const SizedBox(height: AppDimensions.spacingSm),
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              color: skeletonBase,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: skeletonBase,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: AppDimensions.spacingSm),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAyurvedaSetupCard(BuildContext context, bool isDark) {
    final c = AppTheme.primaryColor;
    return TransparentToolbox.buildCard(
      context: context,
      onTap: () {
        HapticFeedback.lightImpact();
        onOpenDetails();
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
            ),
            child: Icon(
              Icons.spa_outlined,
              color: c,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AYURVEDA',
                  style: AppTheme.cardLabelStyle,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  'Discover your constitution',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
        ],
      ),
    );
  }
}
