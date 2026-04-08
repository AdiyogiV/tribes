import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/features/spaces/presentation/pages/gram_creation_page.dart'
    show SpaceCreationPage;
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Empty state shown in the detail panel when no gram is selected (desktop layout).
class GramsEmptyDetailState extends StatelessWidget {
  final bool isDark;

  const GramsEmptyDetailState({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: EmptyStateWidget(
        icon: Icons.grid_view_rounded,
        iconSize: 80,
        iconColor: AppTheme.primaryColor.withValues(alpha: 0.3),
        title: 'Select a gram',
        subtitle: 'Choose from your grams\nto view the chat',
      ),
    );
  }
}

/// Empty / no-grams state shown to authenticated users with no grams yet.
class GramsCreateFirstState extends StatelessWidget {
  const GramsCreateFirstState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80.0),
      child: EmptyStateWidget(
        icon: Icons.groups_outlined,
        iconSize: 64,
        iconColor: AppTheme.primaryColor.withValues(alpha: 0.6),
        title: 'Create Your First Gram',
        subtitle:
            'Start a gram and invite your friends to share content together',
        action: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpaceCreationPage(),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Create Gram'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }
}

/// Empty state shown to unauthenticated users when there are no public grams.
class GramsNoPublicState extends StatelessWidget {
  const GramsNoPublicState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80.0),
      child: EmptyStateWidget(
        icon: Icons.groups_outlined,
        iconSize: 64,
        title: 'No public grams yet',
        subtitle: 'Sign in to create or join grams',
      ),
    );
  }
}

/// Empty search results state shown when a query matches nothing.
class GramsSearchEmptyState extends StatelessWidget {
  const GramsSearchEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppHeaderStyle.contentTopPadding),
      child: const Column(
        children: [
          SizedBox(height: AppDimensions.spacingHero),
          EmptyStateWidget(
            icon: Icons.search_off,
            iconSize: 64,
            title: 'No grams found',
            subtitle: 'Try a different search term',
          ),
        ],
      ),
    );
  }
}
