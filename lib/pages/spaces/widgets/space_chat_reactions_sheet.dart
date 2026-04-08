import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Bottom sheet showing who reacted to a message and with which emoji.
class ReactionsSheet {
  static void show(
    BuildContext context, {
    required ChatMessage message,
    required String? currentUserId,
    required SpaceChatService chatService,
  }) {
    AppBottomSheet.show(
      context,
      maxHeightFraction: 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
            child: Text(
              'Reactions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
              itemCount: message.reactions.length,
              itemBuilder: (context, index) {
                final entry = message.reactions.entries.elementAt(index);
                final userId = entry.key;
                final emoji = entry.value;
                final isCurrentUser = userId == currentUserId;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (context, snapshot) {
                    String userName = 'Loading...';
                    String? userAvatar;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      userName = userData?['name'] ?? 'Unknown';
                      userAvatar = userData?['profilePic'];
                    }

                    if (isCurrentUser) {
                      userName = 'You';
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                        backgroundImage: userAvatar != null
                            ? NetworkImage(userAvatar)
                            : null,
                        child: userAvatar == null
                            ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 24)),
                          if (isCurrentUser) ...[
                            const SizedBox(width: AppDimensions.spacingMd),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                chatService.removeReaction(message.id);
                                if (!kIsWeb) HapticFeedback.lightImpact();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                                ),
                                child: Text(
                                  'Remove',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: isCurrentUser
                          ? () {
                              Navigator.pop(context);
                              chatService.removeReaction(message.id);
                              if (!kIsWeb) HapticFeedback.lightImpact();
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
