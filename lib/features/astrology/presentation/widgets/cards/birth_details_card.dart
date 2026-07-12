import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/immersive_setup_page.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_formatters.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Displays birth details - aligned with samvat card style
class BirthDetailsCard extends StatelessWidget {
  final AstrologyProfile profile;
  final VoidCallback? onEditPressed;

  const BirthDetailsCard({
    super.key,
    required this.profile,
    this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    if (profile.birthPlace == null || profile.birthDate == null) {
      return const SizedBox.shrink();
    }

    final birthDate = profile.birthDate!;
    final weekday = AstrologyFormatters.getWeekdayName(birthDate.weekday);
    final monthName = AstrologyFormatters.getMonthName(birthDate.month);
    final formattedTime =
        AstrologyFormatters.formatTime12Hour(profile.birthTime);
    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        onTap: onEditPressed ?? () => _editProfile(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Birth Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              // Date
              _buildComponent(
                'Date',
                '$weekday, ${birthDate.day} $monthName ${birthDate.year}',
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              // Time
              _buildComponent(
                'Time',
                profile.timeZone != null
                    ? '$formattedTime • ${profile.timeZone}'
                    : formattedTime,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              // Place
              _buildComponent('Place', profile.birthPlace ?? '—'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponent(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
              height: 1.3,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final result = await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => const ImmersiveSetupPage(),
      ),
    );

    if (result == true && context.mounted) {
      showCustomSnackBar(context, message: 'Birth details updated', duration: const Duration(seconds: 2));
    }
  }
}
