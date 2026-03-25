import 'package:flutter/material.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/user_avatar.dart';

/// Controller for managing mentions in a text field
class MentionsController {
  final TextEditingController textController;
  final String spaceId;
  final SpaceChatService _chatService = SpaceChatService();

  List<MentionableUser> _cachedUsers = [];
  List<MentionableUser> _filteredUsers = [];
  bool _isLoading = false;
  int _mentionStartIndex = -1;

  VoidCallback? _onStateChanged;

  MentionsController({
    required this.textController,
    required this.spaceId,
  }) {
    textController.addListener(_onTextChanged);
    _loadUsers();
  }

  bool get isShowingSuggestions =>
      _mentionStartIndex >= 0 && _filteredUsers.isNotEmpty;
  List<MentionableUser> get suggestions => _filteredUsers;
  bool get isLoading => _isLoading;

  void setOnStateChanged(VoidCallback callback) {
    _onStateChanged = callback;
  }

  void dispose() {
    textController.removeListener(_onTextChanged);
  }

  Future<void> _loadUsers() async {
    _isLoading = true;
    _onStateChanged?.call();

    try {
      _cachedUsers = await _chatService.getMentionableUsers(spaceId);
    } catch (e) {
      _cachedUsers = [];
    }

    _isLoading = false;
    _onStateChanged?.call();
  }

  void _onTextChanged() {
    final text = textController.text;
    final selection = textController.selection;

    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _closeSuggestions();
      return;
    }

    final cursorPos = selection.baseOffset;

    // Find the @ symbol before cursor
    int atIndex = -1;
    for (int i = cursorPos - 1; i >= 0; i--) {
      final char = text[i];
      if (char == '@') {
        atIndex = i;
        break;
      }
      // Stop if we hit whitespace or another special character
      if (char == ' ' || char == '\n') {
        break;
      }
    }

    if (atIndex >= 0) {
      // We found an @, now get the query after it
      final query = text.substring(atIndex + 1, cursorPos).toLowerCase();
      _mentionStartIndex = atIndex;
      _filterUsers(query);
    } else {
      _closeSuggestions();
    }
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      _filteredUsers = _cachedUsers.take(5).toList();
    } else {
      _filteredUsers = _cachedUsers
          .where((u) => u.name.toLowerCase().contains(query))
          .take(5)
          .toList();
    }
    _onStateChanged?.call();
  }

  void _closeSuggestions() {
    if (_mentionStartIndex >= 0) {
      _mentionStartIndex = -1;
      _filteredUsers = [];
      _onStateChanged?.call();
    }
  }

  /// Insert a mention into the text field
  void insertMention(MentionableUser user) {
    if (_mentionStartIndex < 0) return;

    final text = textController.text;
    final cursorPos = textController.selection.baseOffset;

    // Replace @query with @username
    final beforeMention = text.substring(0, _mentionStartIndex);
    final afterMention =
        cursorPos < text.length ? text.substring(cursorPos) : '';
    final mention = '@${user.name} ';

    final newText = beforeMention + mention + afterMention;
    final newCursorPos = _mentionStartIndex + mention.length;

    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    _closeSuggestions();
  }

  /// Extract mentioned user IDs from text
  static List<String> extractMentionedUserIds(
      String text, List<MentionableUser> users) {
    final mentionedIds = <String>[];
    final mentionPattern = RegExp(r'@(\w+)');

    for (final match in mentionPattern.allMatches(text)) {
      final name = match.group(1)?.toLowerCase();
      if (name != null) {
        final user = users.firstWhere(
          (u) => u.name.toLowerCase() == name,
          orElse: () => MentionableUser(userId: '', name: ''),
        );
        if (user.userId.isNotEmpty && !mentionedIds.contains(user.userId)) {
          mentionedIds.add(user.userId);
        }
      }
    }

    return mentionedIds;
  }
}

/// Overlay widget that shows mention suggestions
class MentionsOverlay extends StatelessWidget {
  final MentionsController controller;
  final double? maxHeight;

  const MentionsOverlay({
    super.key,
    required this.controller,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isShowingSuggestions) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? 200,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardDarkColor.withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: controller.suggestions.length,
          itemBuilder: (context, index) {
            final user = controller.suggestions[index];
            return _MentionSuggestionTile(
              user: user,
              onTap: () => controller.insertMention(user),
            );
          },
        ),
      ),
    );
  }
}

class _MentionSuggestionTile extends StatelessWidget {
  final MentionableUser user;
  final VoidCallback onTap;

  const _MentionSuggestionTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            UserAvatar(
              userId: user.userId,
              imageUrl: user.avatar,
              size: 32,
              loadFromFirestore: user.avatar == null,
              nameInitials: user.name.isNotEmpty
                  ? user.name.substring(0, 1).toUpperCase()
                  : 'U',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '@${user.name}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
