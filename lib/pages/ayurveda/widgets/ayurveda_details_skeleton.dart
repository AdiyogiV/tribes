import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:flutter/material.dart';

class AyurvedaDetailsSkeleton extends StatelessWidget {
  const AyurvedaDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            SkeletonBox(height: 200, borderRadius: 20),
            SizedBox(height: 16),
            SkeletonBox(height: 150, borderRadius: 20),
          ],
        ),
      ),
    );
  }
}
