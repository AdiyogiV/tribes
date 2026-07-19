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
        height: 56,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161618) : const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: <Widget>[
            GramPicture(
              displayPicture: spaceData['displayPicture'],
              size: 40.0,
              spaceId: spaceData['id'] ?? '',
              borderRadius: 12.0, // Modern squircle instead of circle
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? 'Gram',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (type != null)
                    Text(
                      _getSpaceTypeLabel(type).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: getColorFromSpaceType(type),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    }

    // Full card version - Complete Rethink (Minimalist Chic & Editorial)
    final Color cardBg = isDark ? const Color(0xFF101012) : const Color(0xFFFFFFFF);
    final Color borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04);
    final Color shadowColor = isDark ? Colors.black.withValues(alpha: 0.6) : const Color(0xFF1D1D2B).withValues(alpha: 0.08);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppHeaderStyle.contentHorizontalPadding, 
        vertical: 12
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Ultra-modern large Squircle Picture
                  Hero(
                    tag: 'gram_pic_${spaceData['id']}',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black54 : Colors.black12,
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ]
                      ),
                      child: GramPicture(
                        displayPicture: spaceData['displayPicture'],
                        size: 88, // Substantially larger for editorial feel
                        spaceId: spaceData['id'] ?? '',
                        borderRadius: 24.0, 
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // Name and Actions Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                name ?? 'Gram',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0A0A0C),
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                            // Action icons nested in a chic unified pill
                            Container(
                              margin: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Chic Pill Badge for space type
                        if (type != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: getColorFromSpaceType(type).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: getColorFromSpaceType(type).withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getSpaceTypeLabel(type).toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: getColorFromSpaceType(type),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Bottom row section
              Builder(
                builder: (context) {
                  final bottomWidget = _buildBottomRow(
                    spaceData['id'] ?? '',
                    isPublicSpace: type == null || isPublicSpaceType(type),
                  );
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: bottomWidget,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

"""

new_content = pattern.sub(new_ui, content)

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'w') as f:
    f.write(new_content)

print("Rethink applied.")
