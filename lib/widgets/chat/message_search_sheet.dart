import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/widgets/user_avatar.dart';

/// Result callback for message search
typedef OnMessageSelected = void Function(ChatMessage message);

/// Bottom sheet for searching messages within a conversation
class MessageSearchSheet extends StatefulWidget {
  final String spaceId;
  final OnMessageSelected onMessageSelected;

  const MessageSearchSheet({
    super.key,
    required this.spaceId,
    required this.onMessageSelected,
  });

  /// Show the search sheet as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required String spaceId,
    required OnMessageSelected onMessageSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageSearchSheet(
        spaceId: spaceId,
        onMessageSelected: onMessageSelected,
      ),
    );
  }

  @override
  State<MessageSearchSheet> createState() => _MessageSearchSheetState();
}

class _MessageSearchSheetState extends State<MessageSearchSheet> {
  final SpaceChatService _chatService = SpaceChatService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _results = [];
  bool _isSearching = false;
  String _lastQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }

    // Debounce search
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query == _lastQuery) return;

    setState(() {
      _isSearching = true;
      _lastQuery = query;
    });

    try {
      final results = await _chatService.searchMessages(widget.spaceId, query);

      if (mounted && query == _lastQuery) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = Responsive.isDesktop(context);

    // Responsive sizing: smaller on desktop, larger on mobile
    final sheetHeight = isDesktop
        ? (screenHeight * 0.6).clamp(400.0, 600.0)
        : screenHeight * 0.75;
    final maxWidth = isDesktop ? 500.0 : screenWidth;

    return Center(
      child: Container(
        width: maxWidth,
        height: sheetHeight,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDarkColor : Colors.white,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(20),
            // On desktop, round all corners for dialog-like appearance
            bottom: isDesktop ? const Radius.circular(20) : Radius.zero,
          ),
          // Add shadow on desktop for better visibility
          boxShadow: isDesktop
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ]
              : null,
        ),
        child: Column(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Search messages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: Icon(
                            Icons.clear,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                            size: 20,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),

            const SizedBox(height: 8),

            // Results
            Expanded(
              child: _buildResults(),
            ),

            // Bottom padding for keyboard
            SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Search for messages',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No messages found',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final message = _results[index];
        return _SearchResultTile(
          message: message,
          query: _searchController.text,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            widget.onMessageSelected(message);
          },
        );
      },
    );
  }
}

/// A tile displaying a search result
class _SearchResultTile extends StatelessWidget {
  final ChatMessage message;
  final String query;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.message,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: UserAvatar(
        userId: message.senderId,
        imageUrl: message.senderAvatar,
        size: 40,
        loadFromFirestore: message.senderAvatar == null,
        nameInitials: message.senderName.isNotEmpty
            ? message.senderName.substring(0, 1).toUpperCase()
            : 'U',
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              message.senderName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            dateFormat.format(message.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          _buildHighlightedText(
            message.content,
            query,
            isDark,
          ),
          const SizedBox(height: 2),
          Text(
            timeFormat.format(message.timestamp),
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, bool isDark) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final normalizedText = text.toLowerCase();
    final normalizedQuery = query.toLowerCase();
    final index = normalizedText.indexOf(normalizedQuery);

    if (index < 0) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Show context around the match
    int start = (index - 20).clamp(0, text.length);
    int end = (index + query.length + 50).clamp(0, text.length);

    String displayText = text.substring(start, end);
    if (start > 0) displayText = '...$displayText';
    if (end < text.length) displayText = '$displayText...';

    final highlightIndex = displayText.toLowerCase().indexOf(normalizedQuery);

    if (highlightIndex < 0) {
      return Text(
        displayText,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: displayText.substring(0, highlightIndex),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          TextSpan(
            text: displayText.substring(
              highlightIndex,
              highlightIndex + query.length,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
          ),
          TextSpan(
            text: displayText.substring(highlightIndex + query.length),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
