import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Internal search content widget for TransparentToolbox.search()
class SearchContent extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode focusNode;
  final Function(String) onSearchChanged;
  final String hintText;

  const SearchContent({
    super.key,
    required this.searchController,
    required this.focusNode,
    required this.onSearchChanged,
    required this.hintText,
  });

  @override
  State<SearchContent> createState() => SearchContentState();
}

class SearchContentState extends State<SearchContent> {
  bool _hasText = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.searchController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _onFocusChanged() {
    final hasFocus = widget.focusNode.hasFocus;
    if (hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search text field - optimized for fast response
        Expanded(
          child: TextField(
            controller: widget.searchController,
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 0,
              ),
              // Reduce intrinsic height for faster layout
              isDense: true,
            ),
            style: TextStyle(
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
              fontSize: AppTheme.holyCowTextSize,
              fontWeight: FontWeight.w500,
            ),
            textInputAction: TextInputAction.search,
            // Faster keyboard appearance
            autofocus: false,
            enableInteractiveSelection: true,
            onChanged: widget.onSearchChanged,
            onTap: () {
              // Ensure focus is requested immediately on tap
              if (!widget.focusNode.hasFocus) {
                widget.focusNode.requestFocus();
              }
            },
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        // Search/Close icon button (like HolyCow's send button)
        SizedBox(
          width: 64,
          height: 70,
          child: Opacity(
            opacity: 1.0,
            child: IconButton(
              onPressed: (_hasText || _hasFocus) ? _clearSearch : null,
              icon: Icon(
                (_hasText || _hasFocus) ? Icons.close : Icons.search,
                color: (_hasText || _hasFocus)
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.85),
                size: 28,
                shadows: (_hasText || _hasFocus)
                    ? [
                        Shadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ]
                    : null,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: (_hasText || _hasFocus)
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _clearSearch() {
    widget.searchController.clear();
    widget.onSearchChanged('');
    widget.focusNode.unfocus(); // Close keyboard
  }
}
