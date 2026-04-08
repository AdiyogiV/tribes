import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/stories/pages/story_composer_page.dart';
import 'package:aurogram/shared/presentation/widgets/media/media_type_selector.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Instagram-like creation hub that appears when swiping right from feed
/// Shows options to create a new post or story
class CreationHubPage extends StatefulWidget {
  const CreationHubPage({super.key});

  @override
  State<CreationHubPage> createState() => _CreationHubPageState();
}

class _CreationHubPageState extends State<CreationHubPage> {
  void _createPost(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showLoginBottomSheet(context);
      return;
    }
    // Open post creation dialog for profile posts
    MediaTypeSelector.showMediaTypeSelection(
      context: context,
      space: 'profile', // Special marker for profile posts
      isProfilePost: true, // Indicates profile context
    );
  }

  void _createStory(BuildContext context) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showLoginBottomSheet(context);
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const StoryComposerPage(),
      ),
    );
    // If story was posted, we can refresh the feed or show a success message
    if (result == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppHeaderStyle.buildStandardAppBar(
        context: context,
        title: 'Create',
        automaticallyImplyLeading: false,
        leadingWidget: const SizedBox.shrink(), // Hide app icon
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Post option
              _CreationOption(
                icon: CupertinoIcons.square_grid_2x2,
                title: 'Create Post',
                subtitle: 'Share photos, videos, or notes',
                gradient: LinearGradient(
                  colors: [
                    AppTheme.indigoColor, // Indigo
                    AppTheme.pinkAccent, // Pink
                  ],
                ),
                onTap: () => _createPost(context),
              ),

              const SizedBox(height: AppDimensions.spacingXxl),

              // Story option
              _CreationOption(
                icon: CupertinoIcons.camera_fill,
                title: 'Create Story',
                subtitle: 'Share moments that disappear in 24h',
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0EA5E9), // Sky blue
                    AppTheme.emeraldGreen, // Green
                  ],
                ),
                onTap: () => _createStory(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual creation option card
class _CreationOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _CreationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingXxl),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingXl),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSmMd),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow icon
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
