import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/models/dm_conversation.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/chat/chat_dialogs.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/pages/ai/widgets/recent_conversations_list.dart';
import 'package:aurogram/pages/ai/widgets/recent_conversations_states.dart';

/// Page to display recent AI conversations
/// Accessed from HolyCow page header
class RecentConversationsPage extends StatefulWidget {
  final Function(String conversationId)? onConversationSelected;

  const RecentConversationsPage({
    super.key,
    this.onConversationSelected,
  });

  @override
  State<RecentConversationsPage> createState() => _RecentConversationsPageState();
}

class _RecentConversationsPageState extends State<RecentConversationsPage> {
  int _conversationsLimit = 15;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
    });
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    HapticFeedback.lightImpact();
    
    // Small delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => _searchFocusNode.unfocus(),
        child: Stack(
          children: [
            // Main content
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                _buildAppBar(),
                CupertinoSliverRefreshControl(
                  onRefresh: _handleRefresh,
                  builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
                    return const SizedBox.shrink();
                  },
                ),
                SliverToBoxAdapter(
                  child: _buildContent(),
                ),
                // Bottom padding for search bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
            // Search bar at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: TransparentToolbox.search(
                searchController: _searchController,
                focusNode: _searchFocusNode,
                onSearchChanged: _onSearchChanged,
                hintText: 'Search conversations',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return AppHeaderStyle.buildStandardHeader(
      context: context,
      title: 'holycow chats',
      leadingWidget: AppHeaderStyle.buildCompactIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      ),
      actionButton: AppHeaderStyle.buildCompactIconButton(
        icon: Icons.delete_outline_rounded,
        onPressed: () {
          HapticFeedback.lightImpact();
          ChatDialogs.showClearHistoryDialog(context);
        },
        tooltip: 'Clear History',
      ),
      showSearchField: false,
      backgroundStyle: HeaderBackgroundStyle.gradient,
      isRefreshing: _isRefreshing,
    );
  }

  Widget _buildContent() {
    return Consumer<AiChatProvider>(
      builder: (context, provider, child) {
        if (!provider.isUserAuthenticated) {
          return const RecentConversationsSignInPrompt();
        }

        return StreamBuilder<List<DmConversation>>(
          stream: provider.getRecentAiConversations(limit: _conversationsLimit),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const RecentConversationsSkeleton();
            }

            if (snapshot.hasError) {
              return const RecentConversationsError();
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const RecentConversationsEmpty();
            }

            final conversations = snapshot.data!;
            
            // Filter by search query - search in both firstUserMessage (user's question) and lastMessageContent
            final filteredConversations = _searchQuery.isEmpty
                ? conversations
                : conversations.where((conv) {
                    final userMessage = (conv.firstUserMessage ?? '').toLowerCase();
                    final lastContent = (conv.lastMessageContent ?? '').toLowerCase();
                    return userMessage.contains(_searchQuery) || lastContent.contains(_searchQuery);
                  }).toList();

            if (filteredConversations.isEmpty && _searchQuery.isNotEmpty) {
              return const RecentConversationsNoResults();
            }

            return RecentConversationsList(
              conversations: filteredConversations,
              conversationsLimit: _conversationsLimit,
              onLoadMore: () {
                setState(() => _conversationsLimit += 10);
              },
              onSelectConversation: (conversation) {
                provider.loadConversation(conversation.id);
                if (widget.onConversationSelected != null) {
                  widget.onConversationSelected!(conversation.id);
                }
                Navigator.pop(context);
              },
              onShowOptions: (conversation) {
                _showConversationOptions(conversation, provider);
              },
            );
          },
        );
      },
    );
  }

  void _showConversationOptions(DmConversation conversation, AiChatProvider provider) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              provider.loadConversation(conversation.id);
              if (widget.onConversationSelected != null) {
                widget.onConversationSelected!(conversation.id);
              }
              Navigator.pop(this.context);
            },
            child: const Text('Continue Conversation'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete single conversation
              HapticFeedback.lightImpact();
            },
            child: const Text('Delete Conversation'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

}
