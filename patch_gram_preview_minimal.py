import sys

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'r') as f:
    content = f.read()

start_marker = '  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {'
end_marker = '  @override\n  bool get wantKeepAlive => true;'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

new_code = '''  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {
    final String? name = spaceData['name'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fgColor = isDark ? Colors.white : Colors.black;
    final Color subtleText = isDark ? const Color(0xFF666666) : const Color(0xFF999999);
    final Color dividerColor = isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE);

    if (widget.compact) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          name?.toLowerCase() ?? 'gram',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: fgColor,
            letterSpacing: -0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // Super Minimal List Item
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '#',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: subtleText.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name?.toLowerCase() ?? 'gram',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: fgColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (widget.lastUpdated != null)
            _buildLastUpdatedIndicator(subtleText),
        ],
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
        TimeDisplay.getCompactTimestamp(dt).toLowerCase(),
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

'''

with open('lib/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart', 'w') as f:
    f.write(content[:start_idx] + new_code + content[end_idx:])
