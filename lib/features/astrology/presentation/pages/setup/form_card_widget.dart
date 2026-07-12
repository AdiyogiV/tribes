import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Expandable form section used in the astrology setup page.
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
    final c = primaryColor;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: c.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: InkWell(
        onTap: () {
          onToggle(index);
          HapticFeedback.selectionClick();
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: c.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16,
                      color: c,
                    ),
                  ),
                ],
              ),

              // Content (animated)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 32, bottom: 8),
                  child: content,
                ),
                crossFadeState: isActive
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
