import re

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'r') as f:
    content = f.read()

pattern = re.compile(r'  Widget _buildSpacePreview\(Map<String, dynamic> spaceData\) \{.*?(?=  /// Bottom row that only renders when there\'s actual content)', re.DOTALL)

new_ui = """  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {
    final String? name = spaceData['name'];
    final SpaceType? type = spaceData['spaceType'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Minimalist Monochrome Palette
    final Color bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final Color fgColor = isDark ? Colors.white : Colors.black;
    final Color greyText = isDark ? const Color(0xFF888888) : const Color(0xFF777777);
    final Color subtleBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);

    if (widget.compact) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: subtleBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GramPicture(
              displayPicture: spaceData['displayPicture'],
              size: 32.0,
              spaceId: spaceData['id'] ?? '',
              borderRadius: 10.0,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name ?? 'Gram',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: greyText.withValues(alpha: 0.5),
            ),
          ],
        ),
      );
    }

    // Full Card Version - True Minimalist, Black/White Editorial Vibe
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding, 
        0, 
        AppHeaderStyle.contentHorizontalPadding, 
        16
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Minimal Avatar Shape
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: subtleBg,
                  ),
                  child: GramPicture(
                    displayPicture: spaceData['displayPicture'],
                    size: 52,
                    spaceId: spaceData['id'] ?? '',
                    borderRadius: 14.0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name ?? 'Gram',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: fgColor,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                          ),
                          // Actions: clean icons
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 4),
                      // Space Type Indicator (Monochrome text)
                      if (type != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: greyText.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getSpaceTypeLabel(type).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: greyText,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            Builder(
              builder: (context) {
                final bottomWidget = _buildBottomRow(
                  spaceData['id'] ?? '',
                  isPublicSpace: type == null || isPublicSpaceType(type),
                );
                
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: bottomWidget,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

"""

new_content = pattern.sub(new_ui, content)

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'w') as f:
    f.write(new_content)

print("Minimal replacement complete.")
