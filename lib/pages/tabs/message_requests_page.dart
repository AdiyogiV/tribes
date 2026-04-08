import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/pages/spaces/space_chat_screen.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Instagram-style Message Requests page
/// Shows pending message requests that require approval
class MessageRequestsPage extends StatefulWidget {
  const MessageRequestsPage({super.key});

  @override
  State<MessageRequestsPage> createState() => _MessageRequestsPageState();
}

class _MessageRequestsPageState extends State<MessageRequestsPage> {
  final SpaceChatService _chatService = SpaceChatService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.scaffoldDarkColor : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Message Requests',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _currentUser == null
          ? _buildEmptyState('Please log in to view message requests')
          : StreamBuilder<List<DmConversation>>(
              stream: _chatService.getUserDmConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  return _buildEmptyState('Error loading message requests');
                }

                final conversations = snapshot.data ?? [];
                final pendingRequests = conversations.where((c) =>
                  c.status == 'pending' &&
                  c.requestedBy != _currentUser?.uid
                ).toList();

                if (pendingRequests.isEmpty) {
                  return _buildEmptyState('No message requests');
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(pendingRequests[index], isDark);
                  },
                );
              },
            ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
          child: SkeletonListItem(),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(DmConversation request, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkColor : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child: Row(
              children: [
                // Avatar
                UserAvatar(
                  userId: request.otherUserId,
                  size: 56,
                  loadFromFirestore: true,
                  nameInitials: request.otherUserId.isNotEmpty
                      ? request.otherUserId[0].toUpperCase()
                      : 'U',
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.spaceName ?? request.otherUserId,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        'Wants to send you a message',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Message preview if available
          if (request.lastMessageContent != null &&
              request.lastMessageContent!.isNotEmpty) ...[
            Divider(
              height: 1,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              child: Text(
                request.lastMessageContent!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child:               Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineRequest(request.id),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.errorColor,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptRequest(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(DmConversation request) async {
    // Navigate to chat screen first (Instagram-style: view messages then accept)
    final space = Space(
      id: request.id,
      name: request.spaceName ?? request.otherUserId,
      searchName: 'dm_${request.otherUserId}',
      description: 'Direct message conversation',
      spaceType: SpaceType.private,
      limitedVisibility: false,
    );

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SpaceChatScreen(
          spaceId: request.id,
          space: space,
          otherUserId: request.otherUserId,
        ),
      ),
    );
  }

  Future<void> _declineRequest(String conversationId) async {
    final success = await _chatService.declineMessageRequest(conversationId);
    if (!mounted) return;

    if (success) {
      showCustomSnackBar(context, message: 'Message request declined', backgroundColor: AppTheme.primaryColor, duration: const Duration(seconds: 2));
    } else {
      showCustomSnackBar(context, message: 'Failed to decline request', backgroundColor: AppTheme.errorColor);
    }
  }
}
