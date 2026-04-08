import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

/// Bottom sheet for conversation management options (pin, mute, archive)
class ConversationOptionsSheet extends StatefulWidget {
  final String conversationId;
  final String conversationName;
  final bool initialIsPinned;
  final bool initialIsMuted;
  final bool initialIsArchived;
  final VoidCallback? onSettingsChanged;

  const ConversationOptionsSheet({
    super.key,
    required this.conversationId,
    required this.conversationName,
    this.initialIsPinned = false,
    this.initialIsMuted = false,
    this.initialIsArchived = false,
    this.onSettingsChanged,
  });

  /// Show the options sheet
  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    required String conversationName,
    bool isPinned = false,
    bool isMuted = false,
    bool isArchived = false,
    VoidCallback? onSettingsChanged,
  }) {
    return AppBottomSheet.show(
      context,
      child: ConversationOptionsSheet(
        conversationId: conversationId,
        conversationName: conversationName,
        initialIsPinned: isPinned,
        initialIsMuted: isMuted,
        initialIsArchived: isArchived,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  State<ConversationOptionsSheet> createState() =>
      _ConversationOptionsSheetState();
}

class _ConversationOptionsSheetState extends State<ConversationOptionsSheet> {
  final SpaceChatService _chatService = SpaceChatService();

  late bool _isPinned;
  late bool _isMuted;
  late bool _isArchived;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.initialIsPinned;
    _isMuted = widget.initialIsMuted;
    _isArchived = widget.initialIsArchived;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings =
          await _chatService.getConversationSettings(widget.conversationId);
      if (mounted) {
        setState(() {
          _isPinned = settings['isPinned'] as bool? ?? widget.initialIsPinned;
          _isMuted = settings['isMuted'] as bool? ?? widget.initialIsMuted;
          _isArchived =
              settings['isArchived'] as bool? ?? widget.initialIsArchived;
        });
      }
    } catch (e) {
      // Use initial values on error
    }
  }

  Future<void> _togglePin() async {
    HapticFeedback.lightImpact();
    final newValue = !_isPinned;
    setState(() => _isPinned = newValue);

    try {
      await _chatService.pinConversation(widget.conversationId, newValue);
      widget.onSettingsChanged?.call();
    } catch (e) {
      setState(() => _isPinned = !newValue);
      _showError('Failed to ${newValue ? 'pin' : 'unpin'} conversation');
    }
  }

  Future<void> _toggleMute() async {
    HapticFeedback.lightImpact();

    if (_isMuted) {
      // Unmute
      setState(() => _isMuted = false);
      try {
        await _chatService.muteConversation(widget.conversationId, false);
        widget.onSettingsChanged?.call();
      } catch (e) {
        setState(() => _isMuted = true);
        _showError('Failed to unmute conversation');
      }
    } else {
      // Show mute duration options
      _showMuteDurationPicker();
    }
  }

  void _showMuteDurationPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Mute notifications'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _muteForDuration(const Duration(hours: 1), '1 hour');
            },
            child: const Text('For 1 hour'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _muteForDuration(const Duration(hours: 8), '8 hours');
            },
            child: const Text('For 8 hours'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _muteForDuration(const Duration(days: 1), '1 day');
            },
            child: const Text('For 1 day'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _muteForDuration(const Duration(days: 7), '1 week');
            },
            child: const Text('For 1 week'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _muteForDuration(null, 'indefinitely');
            },
            child: const Text('Until I turn it back on'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _muteForDuration(Duration? duration, String description) async {
    setState(() => _isMuted = true);

    try {
      await _chatService.muteConversation(
        widget.conversationId,
        true,
        duration: duration,
      );
      widget.onSettingsChanged?.call();
      _showSuccess('Muted $description');
    } catch (e) {
      setState(() => _isMuted = false);
      _showError('Failed to mute conversation');
    }
  }

  Future<void> _toggleArchive() async {
    HapticFeedback.lightImpact();
    final newValue = !_isArchived;
    setState(() => _isArchived = newValue);

    try {
      await _chatService.archiveConversation(widget.conversationId, newValue);
      widget.onSettingsChanged?.call();
      if (newValue) {
        Navigator.pop(context);
        _showSuccess('Conversation archived');
      }
    } catch (e) {
      setState(() => _isArchived = !newValue);
      _showError(
          'Failed to ${newValue ? 'archive' : 'unarchive'} conversation');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showCustomSnackBar(context, message: message, backgroundColor: AppTheme.errorColor);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    showCustomSnackBar(context, message: message, backgroundColor: AppTheme.primaryColor);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = isDesktop ? 400.0 : double.infinity;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: isDesktop
            ? const EdgeInsets.symmetric(horizontal: 20)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDarkColor : Colors.white,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(20),
            bottom: isDesktop ? const Radius.circular(20) : Radius.zero,
          ),
          boxShadow: isDesktop
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, -3),
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: Text(
                  widget.conversationName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Options
              _OptionTile(
                icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                title: _isPinned ? 'Unpin conversation' : 'Pin conversation',
                subtitle: _isPinned
                    ? 'Currently pinned to top'
                    : 'Keep at the top of your chats',
                isActive: _isPinned,
                onTap: _togglePin,
              ),

              _OptionTile(
                icon: _isMuted
                    ? Icons.notifications_off
                    : Icons.notifications_outlined,
                title: _isMuted ? 'Unmute notifications' : 'Mute notifications',
                subtitle: _isMuted
                    ? 'Notifications are muted'
                    : 'Stop receiving notifications',
                isActive: _isMuted,
                onTap: _toggleMute,
              ),

              _OptionTile(
                icon: _isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                title: _isArchived
                    ? 'Unarchive conversation'
                    : 'Archive conversation',
                subtitle: _isArchived
                    ? 'Move back to main list'
                    : 'Hide from your chat list',
                isActive: _isArchived,
                onTap: _toggleArchive,
                isDestructive: !_isArchived,
              ),

              const SizedBox(height: AppDimensions.spacingLg),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isActive
        ? AppTheme.primaryColor
        : (isDark ? Colors.white : Colors.black87);
    final destructiveColor = isDestructive ? AppTheme.errorColor : activeColor;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (isActive ? AppTheme.primaryColor : destructiveColor)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
        ),
        child: Icon(
          icon,
          color: isActive ? AppTheme.primaryColor : destructiveColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isActive ? AppTheme.primaryColor : destructiveColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
      trailing: isActive
          ? Icon(
              Icons.check_circle,
              color: AppTheme.primaryColor,
              size: 20,
            )
          : null,
    );
  }
}
