import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/spaces/presentation/pages/gram_creation_page.dart'
    show SpaceCreationPage;
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';

/// Empty feed state widget shown when no posts are available.
///
/// Uses [EmptyStateWidget] for the core empty state, plus a discover section.
class FeedEmptyState extends StatelessWidget {
  const FeedEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingXxl),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingLargeSection),
          EmptyStateWidget(
            icon: CupertinoIcons.sparkles,
            iconSize: 64,
            iconColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            title: 'Welcome to Aurogram!',
            subtitle: 'Create or join a gram to start seeing posts',
            action: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SpaceCreationPage()),
                );
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create Gram'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLargeSection),
          // Discover groups
          const FeedDiscoverGroups(),
        ],
      ),
    );
  }
}

/// Widget that shows discoverable public grams.
class FeedDiscoverGroups extends StatelessWidget {
  const FeedDiscoverGroups({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .where('spaceType', whereIn: [0, 1])
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final publicSpaces = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final spaceType = data['spaceType'] as int? ?? 3;
          final limitedVisibility = data['limitedVisibility'] as bool? ?? false;
          return (spaceType == 0 || spaceType == 1) && !limitedVisibility;
        }).toList();

        if (publicSpaces.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover Grams',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ...publicSpaces.map((doc) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
                  child: GramPreviewBox(gram: doc.id),
                )),
          ],
        );
      },
    );
  }
}
