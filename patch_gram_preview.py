import sys

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'r') as f:
    content = f.read()

start_marker = '  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {'
end_marker = '  @override\n  bool get wantKeepAlive => true;'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

new_code = '''  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {
    final String? name = spaceData['name'];
    final SpaceType? type = spaceData['spaceType'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isPublic = type == null || !isPrivateSpaceType(type);

    // Premium minimal palette
    final Color bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9);
    final Color fgColor = isDark ? Colors.white : Colors.black;
    final Color iconColor = isPublic 
        ? (isDark ? const Color(0xFFA5D6A7) : const Color(0xFF4CAF50)) 
        : (isDark ? const Color(0xFFEF9A9A) : const Color(0xFFE53935));
        
    final Color subtleText = isDark ? const Color(0xFF888888) : const Color(0xFF777777);

    if (widget.compact) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isPublic ? Icons.tag_rounded : Icons.lock_outline_rounded,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name ?? 'Gram',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Full Version - Modern Premium Tile
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding, 
        0, 
        AppHeaderStyle.contentHorizontalPadding, 
        12
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPublic ? Icons.tag_rounded : Icons.lock_outline_rounded,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name ?? 'Gram',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPublic ? 'Public Space' : 'Private Space',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subtleText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.lastUpdated != null)
              _buildLastUpdatedIndicator(subtleText),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdatedIndicator([Color? color]) {
    final ts = widget.lastUpdated;
    if (ts == null) return const SizedBox.shrink();
    final DateTime dt = ts.toDate();
    
    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Text(
        TimeDisplay.getCompactTimestamp(dt),
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

'''

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'w') as f:
    f.write(content[:start_idx] + new_code + content[end_idx:])
