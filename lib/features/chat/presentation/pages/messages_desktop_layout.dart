import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/features/chat/presentation/widgets/embedded_chat_view.dart';
import 'package:aurogram/shared/models/space.dart';

/// Radically minimal, fluid typography-first desktop layout.
class MessagesDesktopLayout extends StatelessWidget {
  final Widget messagesListWidget;
  final String? selectedConversationId;
  final Space? selectedSpace;
  final String? selectedOtherUserId;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;

  const MessagesDesktopLayout({
    super.key,
    required this.messagesListWidget,
    required this.selectedConversationId,
    required this.selectedSpace,
    required this.selectedOtherUserId,
    required this.isRefreshing,
    required this.onRefresh,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
    
    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // Minimalist, borderless sidebar
          SizedBox(
            width: 320,
            child: Container(
              color: bgColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Typography-heavy header
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0, top: 48.0, right: 32.0, bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chats',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          onChanged: onSearchChanged,
                          placeholder: 'Search...',
                          placeholderStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161616) : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 12.0),
                            child: Icon(CupertinoIcons.search, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: messagesListWidget,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Seamless chat area
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.02),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: selectedConversationId != null
                    ? EmbeddedChatView(
                        spaceId: selectedConversationId!,
                        space: selectedSpace,
                        otherUserId: selectedOtherUserId,
                      )
                    : _UltraMinimalEmptyState(isDark: isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UltraMinimalEmptyState extends StatelessWidget {
  final bool isDark;
  
  const _UltraMinimalEmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Select a chat',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
