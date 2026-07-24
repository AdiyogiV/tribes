import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/features/chat/presentation/widgets/embedded_chat_view.dart';
import 'package:aurogram/shared/models/space.dart';
import 'dart:ui';

/// A premium, unified glass-panel layout.
/// Instead of hard, opaque edges that clash with the app's global navigation,
/// this wraps the entire Messages experience in a single, beautiful floating window
/// that respects the underlying app background gradient.
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
  final Widget tabChipsWidget;

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
    required this.tabChipsWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Transparent scaffold so the global app background shows through the margins
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        // Gives breathing room around the massive layout, matching the global nav's style
        padding: const EdgeInsets.only(top: 16.0, bottom: 16.0, right: 16.0, left: 8.0),
        child: Container(
          decoration: BoxDecoration(
            // A subtle glass tint that adapts to light/dark mode
            color: isDark ? const Color(0xFF141414).withOpacity(0.7) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------------------------------------------------------
                  // LEFT PANE: Conversations Sidebar
                  // ---------------------------------------------------------
                  Container(
                    width: 340,
                    decoration: BoxDecoration(
                      // Slightly darker/denser background for the sidebar to differentiate it
                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.02),
                      border: Border(
                        right: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Premium Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Messages',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Integrated Tabs
                              SizedBox(
                                width: double.infinity,
                                child: tabChipsWidget,
                              ),
                              const SizedBox(height: 16),
                              // Sleek Inline Search
                              CupertinoTextField(
                                controller: searchController,
                                focusNode: searchFocusNode,
                                onChanged: onSearchChanged,
                                placeholder: 'Search',
                                placeholderStyle: TextStyle(
                                  color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4),
                                  fontSize: 15,
                                ),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black, 
                                  fontSize: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefix: Padding(
                                  padding: const EdgeInsets.only(left: 12.0),
                                  child: Icon(
                                    CupertinoIcons.search,
                                    size: 16,
                                    color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // The Scrollable List
                        Expanded(
                          child: Stack(
                            children: [
                              RefreshIndicator(
                                onRefresh: () async => onRefresh(),
                                backgroundColor: isDark ? const Color(0xFF222222) : Colors.white,
                                color: isDark ? Colors.white : Colors.black,
                                child: messagesListWidget,
                              ),
                              if (isRefreshing)
                                Positioned(
                                  top: 0, left: 0, right: 0,
                                  child: LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? Colors.white24 : Colors.black26,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // ---------------------------------------------------------
                  // RIGHT PANE: Chat Content
                  // ---------------------------------------------------------
                  Expanded(
                    child: selectedConversationId != null
                        ? EmbeddedChatView(
                            spaceId: selectedConversationId!,
                            space: selectedSpace,
                            otherUserId: selectedOtherUserId,
                          )
                        : _EmptyDesktopState(isDark: isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDesktopState extends StatelessWidget {
  final bool isDark;
  
  const _EmptyDesktopState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            ),
            child: Icon(
              CupertinoIcons.chat_bubble_2,
              size: 48,
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Messages',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a conversation to start chatting',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
