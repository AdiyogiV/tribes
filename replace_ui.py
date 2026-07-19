import re

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'r') as f:
    content = f.read()

pattern = re.compile(r'  Widget _buildSpacePreview\(Map<String, dynamic> spaceData\) \{.*?(?=  /// Bottom row that only renders when there\'s actual content)', re.DOTALL)

new_ui = """  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {
    final String? name = spaceData['name'];
    final SpaceType? type = spaceData['spaceType'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.compact) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: GramPicture(
                displayPicture: spaceData['displayPicture'],
                size: 40.0,
                spaceId: spaceData['id'] ?? '',
                borderRadius: 20.0,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? 'Gram',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (type != null)
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: getColorFromSpaceType(type),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Flexible(
                          child: Text(
                            _getSpaceTypeLabel(type),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppTheme.textSecondaryDarkColor.withValues(alpha: 0.8)
                                  : AppTheme.textSecondaryLightColor.withValues(alpha: 0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    }

    // Full card version - Premium Chic Style
    final Color baseColor = isDark ? const Color(0xFF1E1E24) : const Color(0xFFFFFFFF);
    final Color borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    return Padding(
      padding: EdgeInsets.fromLTRB(AppHeaderStyle.contentHorizontalPadding, 0, AppHeaderStyle.contentHorizontalPadding, AppHeaderStyle.cardVerticalGap),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor.withValues(alpha: isDark ? 0.75 : 0.95),
                    baseColor.withValues(alpha: isDark ? 0.65 : 0.85),
                  ],
                ),
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    ),
                    child: GramPicture(
                      displayPicture: spaceData['displayPicture'],
                      size: 60,
                      spaceId: spaceData['id'] ?? '',
                      borderRadius: 30.0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                name ?? 'Gram',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingSm),
                            GramPreviewActions.buildCallButton(
                              context,
                              spaceData['id'] as String? ?? '',
                              spaceData['name'] as String? ?? 'Gram',
                            ),
                            if (widget.showChatButton) ...[
                              GramPreviewActions.buildChatAndLockIcons(
                                context, spaceData, type, _chatService),
                            ],
                          ],
                        ),
                        _buildBottomRow(
                          spaceData['id'] ?? '',
                          isPublicSpace: type == null || isPublicSpaceType(type),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

"""

new_content = pattern.sub(new_ui, content)

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'w') as f:
    f.write(new_content)

print("Replacement complete.")
