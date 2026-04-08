import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Expandable form card used in the astrology setup page.
class SetupFormCard extends StatelessWidget {
  final int index;
  final int activeSection;
  final String title;
  final String subtitle;
  final Widget content;
  final Color primaryColor;
  final bool dark;
  final ValueChanged<int> onToggle;

  const SetupFormCard({
    super.key,
    required this.index,
    required this.activeSection,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.primaryColor,
    required this.dark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeSection == index;
    final cardColor =
        dark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = primaryColor;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        onTap: () {
          onToggle(index);
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Title & subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXxs),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Expand indicator
                  AnimatedRotation(
                    turns: isActive ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: c.withValues(alpha: 0.4),
                      size: 24,
                    ),
                  ),
                ],
              ),

              // Content (animated)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: content,
                ),
                crossFadeState: isActive
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
