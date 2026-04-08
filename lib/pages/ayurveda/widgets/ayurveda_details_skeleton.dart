import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

class AyurvedaDetailsSkeleton extends StatelessWidget {
  const AyurvedaDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          children: const [
            SkeletonBox(height: 200, borderRadius: 20),
            SizedBox(height: AppDimensions.spacingLg),
            SkeletonBox(height: 150, borderRadius: 20),
          ],
        ),
      ),
    );
  }
}
