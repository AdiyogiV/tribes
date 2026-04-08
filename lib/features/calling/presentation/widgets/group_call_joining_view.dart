import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:flutter/material.dart';

class GroupCallJoiningView extends StatelessWidget {
  final String spaceName;
  final Animation<double> pulseAnimation;

  const GroupCallJoiningView({
    super.key,
    required this.spaceName,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
              child: Icon(
                Icons.videocam,
                size: 50,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          Text(
            'Joining $spaceName...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          AppLoadingIndicator(
            strokeWidth: 2,
          ),
        ],
      ),
    );
  }
}
