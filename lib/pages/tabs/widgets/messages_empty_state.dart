import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';

/// Empty state for the messages list.
///
/// Delegates to [EmptyStateWidget] with chat-specific defaults.
class MessagesEmptyState extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;

  const MessagesEmptyState({
    super.key,
    required this.isDark,
    this.title = 'No messages yet',
    this.subtitle = 'Search for users or invite friends to start chatting',
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.chat_bubble_outline_rounded,
      iconColor: AppTheme.primaryColor.withValues(alpha: 0.3),
      title: title,
      subtitle: subtitle,
    );
  }
}
