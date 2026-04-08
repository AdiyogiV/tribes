import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/features/spaces/presentation/widgets/space_chat_header.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// The header bar for the embedded chat view, matching the wide layout style.
class EmbeddedChatHeader extends StatelessWidget {
  final String spaceId;
  final String? otherUserId;
  final String? displayName;
  final bool isDMConversation;
  final bool isLoadingName;
  final bool isOtherUserOnline;
  final DateTime? otherUserLastSeen;
  final Space? space;
  final VoidCallback? onBack;
  final VoidCallback onNavigateToHeader;
  final VoidCallback onGalleryTap;
  final VoidCallback onSearchTap;
  final bool isDark;

  static const double chatHeaderRowHeight = 56.0;

  const EmbeddedChatHeader({
    super.key,
    required this.spaceId,
    this.otherUserId,
    this.displayName,
    required this.isDMConversation,
    required this.isLoadingName,
    required this.isOtherUserOnline,
    this.otherUserLastSeen,
    this.space,
    this.onBack,
    required this.onNavigateToHeader,
    required this.onGalleryTap,
    required this.onSearchTap,
    required this.isDark,
  });

  double headerHeight(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return topInset +
        AppHeaderStyle.wideLayoutHeaderTitleTopPadding +
        chatHeaderRowHeight +
        10;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final headerBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    return Container(
      height: headerHeight(context),
      decoration: BoxDecoration(
        color: headerBase.withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: topInset + AppHeaderStyle.wideLayoutHeaderTitleTopPadding,
            left: 0,
            right: 0,
            height: chatHeaderRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      onPressed: onBack,
                      icon: Icon(Icons.arrow_back_ios,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    onTap: onNavigateToHeader,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding:
                          EdgeInsets.only(left: onBack != null ? 0 : 16),
                      child: SpaceChatHeaderContent(
                        key: ValueKey(
                            'header_${otherUserId ?? spaceId}'),
                        displayName: displayName,
                        otherUserId: otherUserId,
                        isDMConversation: isDMConversation,
                        isLoadingName: isLoadingName,
                        isOtherUserOnline: isOtherUserOnline,
                        otherUserLastSeen: otherUserLastSeen,
                        space: space,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SpaceChatHeaderActions(
                    spaceId: spaceId,
                    displayName: displayName,
                    otherUserId: otherUserId,
                    isDMConversation: isDMConversation,
                    onInfoTap: onNavigateToHeader,
                    onGalleryTap: onGalleryTap,
                    onSearchTap: onSearchTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A floating action button to scroll to the bottom of the chat.
class ScrollToBottomFAB extends StatelessWidget {
  final VoidCallback onTap;

  const ScrollToBottomFAB({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          barBase.withValues(alpha: 0.75),
                          barBase.withValues(alpha: 0.70),
                        ]
                      : [
                          barBase.withValues(alpha: 0.90),
                          barBase.withValues(alpha: 0.85),
                        ],
                ),
                border: isDark
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      )
                    : null,
              ),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.primary, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
