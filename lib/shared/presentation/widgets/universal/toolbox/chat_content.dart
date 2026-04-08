import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/universal/toolbox/chat_namaste_button.dart';

/// Internal chat content widget for TransparentToolbox.chat()
class ChatContent extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final Function(String) onChanged;
  final String hintText;
  final bool canSend;
  // Namaste button support
  final VoidCallback? onNamaste;
  final bool showNamasteButton;

  const ChatContent({
    super.key,
    required this.messageController,
    required this.focusNode,
    required this.onSend,
    required this.onChanged,
    required this.hintText,
    required this.canSend,
    this.onNamaste,
    this.showNamasteButton = false,
  });

  @override
  State<ChatContent> createState() => ChatContentState();
}

class ChatContentState extends State<ChatContent> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.messageController.text.trim().isNotEmpty;
    widget.messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged(widget.messageController.text);
  }

  void _handleNamasteTap() {
    // The animation is handled by ChatNamasteButton
    // This just triggers the callback after animation completes
    widget.onNamaste?.call();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText || widget.canSend;
    // Show namaste when: no text, showNamasteButton is true, and callback is provided
    final showNamaste =
        !_hasText && widget.showNamasteButton && widget.onNamaste != null;

    return Row(
      children: [
        // Chat text field
        Expanded(
          child: TextField(
            controller: widget.messageController,
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
              isDense: true,
            ),
            style: TextStyle(
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
              fontSize: AppTheme.holyCowTextSize,
              fontWeight: FontWeight.w500,
            ),
            maxLines: null,
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            autofocus: false,
            enableInteractiveSelection: true,
            onSubmitted: canSend ? (_) => widget.onSend() : null,
            onTap: () {
              if (!widget.focusNode.hasFocus) {
                widget.focusNode.requestFocus();
              }
            },
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        // Namaste button OR Send button (not both visible at same time)
        SizedBox(
          width: 48,
          height: 48,
          child: showNamaste
              // Show animated namaste button
              ? ChatNamasteButton(onTap: _handleNamasteTap)
              // Show send button only
              : IconButton(
                  onPressed: canSend ? widget.onSend : null,
                  icon: Icon(
                    canSend
                        ? CupertinoIcons.paperplane_fill
                        : CupertinoIcons.paperplane,
                    color: canSend
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withValues(alpha: 0.3),
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                ),
        ),
      ],
    );
  }
}
