import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/pages/spaces/space_chat_screen.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/search_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aurogram/services/analytics_service.dart';
import 'package:aurogram/services/contact_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/services/namaste_service.dart';
import 'package:aurogram/models/contact_match.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/tabs/widgets/namaste_button.dart';
import 'package:aurogram/pages/tabs/widgets/message_list_item.dart';
import 'package:aurogram/pages/tabs/widgets/message_skeletons.dart';
import 'package:aurogram/pages/tabs/widgets/messages_search_bar.dart';
import 'package:aurogram/pages/tabs/widgets/messages_empty_state.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/widgets/chat/embedded_chat_view.dart';
import 'package:aurogram/widgets/send_me_something/message_card.dart';
import 'package:aurogram/pages/send_me_something/anonymous_message_detail_page.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/services/anonymous_message_service.dart';
import 'package:aurogram/services/share/share_media.dart';
import 'package:aurogram/widgets/send_me_something/share_card_builder.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/utils/performance/image_optimizer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:aurogram/pages/tabs/message_requests_page.dart';
import 'package:aurogram/services/anonymous_message_settings_service.dart';
import 'package:aurogram/pages/helpers/user_settings.dart';
import 'package:aurogram/pages/send_me_something/get_link_screen.dart';

/// Main Messages page that replaces the notifications tab
/// Shows Direct Messages with real-time updates
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

enum _MessagesTab { chats, requests }

class _AnonymousSharePreviewTheme {
  final Color accent;

  const _AnonymousSharePreviewTheme({required this.accent});
}

class _AnonymousShareCardPreview extends StatelessWidget {
  final _AnonymousSharePreviewTheme theme;
  final String? avatarUrl;
  final TextEditingController headingController;
  final TextEditingController subheadingController;
  final FocusNode headingFocusNode;
  final FocusNode subheadingFocusNode;
  final String heading;
  final String subheading;
  final VoidCallback onSave;

  _AnonymousShareCardPreview({
    required this.theme,
    required this.avatarUrl,
    required this.headingController,
    required this.subheadingController,
    required this.headingFocusNode,
    required this.subheadingFocusNode,
    required this.heading,
    required this.subheading,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardRadius = width * 0.06;
        final avatarRadius = width * 0.075;
        final headerFont = width * 0.034;
        final bodyFont = width * 0.042;

        final showAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding:
                  EdgeInsets.only(top: showAvatar ? avatarRadius * 1.35 : 0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        top: width * 0.045,
                        bottom: width * 0.03,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(cardRadius),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: TextField(
                            controller: headingController,
                            focusNode: headingFocusNode,
                            textAlign: TextAlign.center,
                            textAlignVertical: TextAlignVertical.bottom,
                            maxLength: 30,
                            textCapitalization: TextCapitalization.characters,
                            cursorColor: Colors.white,
                            style: TextStyle(
                              fontSize: headerFont,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              counterText: '',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        width * 0.1,
                        width * 0.06,
                        width * 0.1,
                        width * 0.07,
                      ),
                      child: TextField(
                        controller: subheadingController,
                        focusNode: subheadingFocusNode,
                        textAlign: TextAlign.center,
                        maxLength: 60,
                        maxLines: 2,
                        cursorColor: AppTheme.textColor,
                        style: TextStyle(
                          fontSize: bodyFont,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF20212B),
                          height: 1.15,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          counterText: '',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showAvatar)
              Container(
                padding: EdgeInsets.all(avatarRadius * 0.12),
                decoration: BoxDecoration(
                  color: theme.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: avatarRadius * 2,
                    height: avatarRadius * 2,
                    child: ImageOptimizer.buildOptimizedImage(
                      url: avatarUrl!,
                      width: avatarRadius * 2,
                      height: avatarRadius * 2,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(avatarRadius),
                      placeholder: SizedBox(
                        width: avatarRadius * 2,
                        height: avatarRadius * 2,
                        child: ColoredBox(
                          color: theme.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessagesPageState extends State<MessagesPage>
    with AutomaticKeepAliveClientMixin {
  final SpaceChatService _chatService = SpaceChatService();
  final SearchService _searchService = SearchService();
  final ContactService _contactService = ContactService.instance;
  final UserService _userService = UserService();
  final AnonymousMessageService _anonymousService = AnonymousMessageService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  static const String _defaultAnonymousHeading = 'SEND ME SOMETHING';
  static const String _defaultAnonymousSubheading =
      'send me something, anonymously';

  // Track if we're in the middle of a refresh to prevent multiple rebuilds
  bool _isRefreshing = false;

  // Keep a stable stream instance across rebuilds to avoid losing last data
  late Stream<List<DmConversation>> _conversationsStream;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<QueryDocumentSnapshot> _userSearchResults = [];
  bool _isSearchingUsers = false;
  Timer? _searchDebounceTimer;
  String? _lastSearchMetricsKey;
  static const int _minSearchLength = 2;

  // Contact sync state
  ContactSyncResult? _contactResult;
  bool _isLoadingContacts = false;
  bool _hasRequestedContactPermission = false;
  int _contactsNotOnAppLimit = 20; // Pagination limit
  int _conversationsLimit = 50; // Pagination limit for conversations

  // Cache for user names to avoid repeated Firestore calls
  final Map<String, String> _userNameCache = {};
  final Map<String, Future<String>> _userNameFutures = {};

  // Track active user IDs from conversations for deduplication
  Set<String> _activeUserIds = {};

  // Track user IDs that have received namaste (for hiding the button with animation)
  final Set<String> _namastesSentThisSession = {};

  // Desktop master-detail state
  String? _selectedConversationId;
  Space? _selectedSpace;
  String? _selectedOtherUserId;

  int _chatCount = 0;
  List<DmConversation> _cachedConversations = const [];
  Future<String>? _anonymousShareLinkFuture;
  String? _currentUserPhotoUrl;
  String _anonymousHeading = _defaultAnonymousHeading;
  String _anonymousSubheading = _defaultAnonymousSubheading;
  late TextEditingController _anonymousHeadingController;
  late TextEditingController _anonymousSubheadingController;
  late FocusNode _anonymousHeadingFocusNode;
  late FocusNode _anonymousSubheadingFocusNode;
  _MessagesTab _selectedTab = _MessagesTab.chats;

  /// Handle refresh action similar to gallery
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    // Yield a frame so shimmer appears before work starts
    await Future.delayed(Duration.zero);

    try {
      // Clear cache and get fresh stream (this maintains real-time connection)
      _chatService.clearConversationsCache();
      if (mounted) {
        setState(() {
          // Clear temporary namaste tracking so buttons reappear
          _namastesSentThisSession.clear();

          // Get fresh stream - the service will create a new real-time stream
          _conversationsStream = _chatService
              .getUserDmConversations()
              .handleError((error, stackTrace) {
            AppLogger.e('🔥 STREAM ERROR: $error',
                category: LogCategory.ui, error: error);
            AppLogger.e('🔥 STACK TRACE: $stackTrace',
                category: LogCategory.ui);
            return <DmConversation>[];
          });
        });
      }

      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      AppLogger.e('Error during refresh',
          category: LogCategory.general, error: e);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _updateChatCount(int count) {
    if (count == _chatCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _chatCount = count;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _anonymousHeadingController =
        TextEditingController(text: _anonymousHeading);
    _anonymousSubheadingController =
        TextEditingController(text: _anonymousSubheading);
    _anonymousHeadingFocusNode = FocusNode();
    _anonymousSubheadingFocusNode = FocusNode();
    _anonymousHeadingFocusNode.addListener(_handlePromptFocusChange);
    _anonymousSubheadingFocusNode.addListener(_handlePromptFocusChange);

    if (_currentUser != null) {
      _anonymousShareLinkFuture = _fetchAnonymousShareLink();
      _loadCurrentUserPhoto();
    }

    // Initialize a stable stream once. Do not rebuild a new stream every build.
    _conversationsStream =
        _chatService.getUserDmConversations().handleError((error, stackTrace) {
      AppLogger.e('🔥 STREAM ERROR: $error',
          category: LogCategory.ui, error: error);
      AppLogger.e('🔥 STACK TRACE: $stackTrace', category: LogCategory.ui);
      // Return empty list on error to prevent UI hanging
      return <DmConversation>[];
    });

    // Load contacts if cached, otherwise wait for user action
    _loadCachedContacts();
  }

  /// Load cached contacts from local storage (no permission prompt)
  Future<void> _loadCachedContacts() async {
    // Ensure current user's phone is indexed (backfill)
    await _userService.ensurePhoneIndexed();

    // Initialize service to load from storage
    await _contactService.initialize();

    final cached = _contactService.cachedResult;
    if (cached != null && cached.hasPermission && mounted) {
      setState(() => _contactResult = cached);
    }
  }

  /// Sync contacts with permission check
  Future<void> _syncContacts(
      {bool forceRefresh = false, bool showPermissionDialog = true}) async {
    if (_isLoadingContacts) return;

    // Show permission explanation dialog first (if first time)
    if (showPermissionDialog && !_hasRequestedContactPermission) {
      final shouldProceed = await _showContactPermissionDialog();
      if (!shouldProceed) return;
    }

    setState(() => _isLoadingContacts = true);
    HapticFeedback.lightImpact();

    try {
      final result = await _contactService.sync(forceRefresh: forceRefresh);
      if (mounted) {
        HapticFeedback.mediumImpact();

        setState(() {
          _contactResult = result;
          _isLoadingContacts = false;
          _hasRequestedContactPermission = true;
        });

        // Show success feedback
        if (result.hasPermission && !result.isEmpty) {
          final onAppCount = result.onApp.length;
          final message = onAppCount > 0
              ? '🎉 Found $onAppCount ${onAppCount == 1 ? 'friend' : 'friends'} on Aurogram!'
              : 'Contacts synced! Invite friends to join.';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              backgroundColor:
                  onAppCount > 0 ? AppTheme.grassGreen : AppTheme.primaryColor,
              duration: Duration(seconds: 2),
            ),
          );
        } else if (!result.hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact permission is required to find friends'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.warningColor,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  // Open app settings
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.e('Error syncing contacts', category: LogCategory.ui, error: e);
      if (mounted) {
        setState(() => _isLoadingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to sync contacts')),
                TextButton(
                  onPressed: () => _syncContacts(
                      forceRefresh: true, showPermissionDialog: false),
                  child: Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<bool> _showContactPermissionDialog() async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Image.asset(
                    'assets/icons/namaste.png',
                    width: 48,
                    height: 48,
                  ),
                  SizedBox(height: 12),
                  Text('Find Friends'),
                ],
              ),
            ),
            content: Text(
              'Aurogram will check your contacts to show who\'s already here.\n\nYour contacts are never stored on our servers - only a secure hash is used for matching.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Not Now'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Find Friends'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _anonymousHeadingController.dispose();
    _anonymousSubheadingController.dispose();
    _anonymousHeadingFocusNode.dispose();
    _anonymousSubheadingFocusNode.dispose();
    // Clear the stream cache when the page is disposed
    _chatService.clearConversationsCache();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  // Helper methods - moved before build() to fix "referenced before declaration" errors
  Future<String> _fetchUserNameFromFirestore(String userId) async {
    try {
      // Check cache first - if we have a cached name, use it for optimization
      final cachedName = _userNameCache[userId];

      AppLogger.i('Messages conversation name lookup',
          category: LogCategory.ui,
          data: {'userId': userId, 'hasCachedName': cachedName != null});

      return await _userService.getUserDisplayName(userId,
          cachedName: cachedName);
    } catch (e) {
      AppLogger.w('Error fetching user name for conversation tile',
          category: LogCategory.ui, data: {'error': e.toString()});
      // Return generic fallback instead of "Deleted User" on errors
      return 'User';
    }
  }

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    if (_userNameFutures.containsKey(userId)) {
      return _userNameFutures[userId]!;
    }

    final future = _fetchUserNameFromFirestore(userId);
    _userNameFutures[userId] = future;

    final name = await future;
    _userNameFutures.remove(userId);
    _userNameCache[userId] = name;

    return name;
  }

  bool _areSameUserResults(
      List<QueryDocumentSnapshot> current, List<QueryDocumentSnapshot> next) {
    if (current.length != next.length) return false;
    for (int i = 0; i < current.length; i++) {
      if (current[i].id != next[i].id) return false;
    }
    return true;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w';
    }
  }

  Color _getSpaceTypeColor(SpaceType? type) {
    if (type == null) return AppTheme.primaryColor;
    if (isPrivateSpaceType(type)) {
      return AppTheme.warningColor;
    }
    return AppTheme.successColor;
  }

  String _getSpaceTypeLabel(SpaceType? type) {
    if (type == null) return 'Private';
    return getSpaceTypeName(type);
  }

  String _buildLastMessageTextWithoutTime(DmConversation conversation) {
    if (conversation.lastMessageContent != null &&
        conversation.lastMessageContent!.isNotEmpty) {
      final isGroupSpace = conversation.participants.length > 2;
      final isFromCurrentUser = conversation.lastMessageSenderId ==
          FirebaseAuth.instance.currentUser?.uid;

      String prefix = '';
      if (isGroupSpace && conversation.lastMessageSenderName != null) {
        prefix = isFromCurrentUser
            ? 'You: '
            : '${conversation.lastMessageSenderName}: ';
      } else if (!isGroupSpace && isFromCurrentUser) {
        prefix = 'You: ';
      }

      return '$prefix${conversation.lastMessageContent}';
    }

    if (!conversation.id.startsWith('dm_')) {
      final isGroupSpace = conversation.participants.length > 2;
      if (isGroupSpace) {
        return '${conversation.participants.length} members';
      } else {
        return 'No messages yet';
      }
    }

    return 'Start a conversation';
  }

  Widget _buildUserNameWidget(String userId) {
    if (_userNameCache.containsKey(userId)) {
      return Text(
        _userNameCache[userId]!,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return FutureBuilder<String>(
      future: _getUserName(userId),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return Text(
            snapshot.data!,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return Container(
          height: 14,
          width: 100,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }

  Widget _buildSpaceAvatarCompact(DmConversation conversation) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GramPicture(
            displayPicture: conversation.displayPicture,
            size: 44,
            spaceId: conversation.id,
            borderRadius: 14.0,
          ),
          if (conversation.spaceType != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: _getSpaceTypeColor(conversation.spaceType),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Text(
                    _getSpaceTypeLabel(conversation.spaceType),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openConversation(DmConversation conversation) async {
    final isDM = conversation.id.startsWith('dm_');
    final isGroupSpace = conversation.participants.length > 2;

    String displayName = conversation.spaceName ?? conversation.otherUserId;
    String? otherUserId;

    if (isDM) {
      otherUserId = conversation.otherUserId;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(conversation.otherUserId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            displayName = userData['name'] as String? ??
                userData['nickname'] as String? ??
                conversation.otherUserId;
          }
        }
      } catch (e) {
        AppLogger.w('Error fetching user name for conversation',
            category: LogCategory.ui, data: {'error': e.toString()});
      }
    }

    if (mounted) {
      final space = Space(
        id: conversation.id,
        name: displayName,
        searchName: isDM ? 'dm_${conversation.otherUserId}' : conversation.id,
        description: isDM
            ? 'Direct message conversation'
            : isGroupSpace
                ? 'Gram conversation'
                : 'Private conversation',
        spaceType: SpaceType.private,
        limitedVisibility: false,
      );

      // On wide layout, show chat inline
      if (Responsive.isWideLayout(context)) {
        setState(() {
          _selectedConversationId = conversation.id;
          _selectedSpace = space;
          _selectedOtherUserId = otherUserId;
        });
      } else {
        // On mobile, push the chat screen
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => SpaceChatScreen(
              spaceId: conversation.id,
              space: space,
              otherUserId: otherUserId,
            ),
          ),
        );
      }
    }
  }

  void _openProfile(String userId) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => UserProfilePage(uid: userId),
      ),
    );
  }

  Future<void> _inviteContact(ContactMatch contact) async {
    HapticFeedback.lightImpact();

    try {
      final result = await Share.share(
        '🙏 Namaste! Join me on Aurogram for cosmic insights.\n\nhttps://aurogram.in',
        subject: 'Join me on Aurogram',
      );

      if (result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed) {
        await _contactService.removeFromNotOnApp(contact.phoneHash);

        if (mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _contactResult = _contactService.cachedResult;
          });
        }
      }

      AnalyticsService().trackInviteSent(method: 'contact_invite');
    } catch (e) {
      AppLogger.e('Error inviting contact', category: LogCategory.ui, error: e);
    }
  }

  void _showNamasteError(NamasteResult result) {
    String message;
    if (result.quotaExceeded) {
      message = 'Daily limit reached. You can send 3 namastes per day.';
    } else if (result.alreadySentToday) {
      message = 'Already sent namaste to this person today.';
    } else if (result.blocked) {
      message = 'Unable to send namaste to this user.';
    } else {
      message = 'Failed to send Namaste. Please try again.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.quotaExceeded || result.alreadySentToday
            ? AppTheme.primaryColor
            : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _sendNamasteToContact(ContactMatch contact) async {
    if (contact.userId == null) return;

    // Create or get the DM conversation first
    final dmId = await _chatService.createDirectMessage(contact.userId!);

    // Send via backend (handles everything including chat message)
    final result =
        await NamasteService().sendNamaste(contact.userId!, dmId: dmId);

    if (!mounted) return;

    if (result.success) {
      // Remove from list and persist
      await _contactService.removeFromOnApp(contact.phoneHash);

      setState(() {
        _namastesSentThisSession.add(contact.userId!);
        _contactResult = _contactService.cachedResult;
      });
      final points = result.senderPointsAwarded ?? 0;
      if (points > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+$points Auro for sending Namaste!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } else {
      _showNamasteError(result);
    }
  }

  Future<void> _sendNamasteToUser(String userId) async {
    // Create or get the DM conversation first
    final dmId = await _chatService.createDirectMessage(userId);

    // Send via backend (handles everything including chat message)
    final result = await NamasteService().sendNamaste(userId, dmId: dmId);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _namastesSentThisSession.add(userId);
      });
      final points = result.senderPointsAwarded ?? 0;
      if (points > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+$points Auro for sending Namaste!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } else {
      _showNamasteError(result);
    }
  }

  Widget _buildNamasteIconButton({
    String? userId,
    ContactMatch? contact,
    bool isInvite = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (isInvite && contact != null) {
            _inviteContact(contact);
          } else if (userId != null) {
            _sendNamasteToUser(userId);
          } else if (contact?.userId != null) {
            _sendNamasteToContact(contact!);
          }
        },
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/icons/namaste.png',
            width: 36,
            height: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildNamasteWithArrow({
    String? userId,
    ContactMatch? contact,
  }) {
    final targetUserId = userId ?? contact?.userId;
    final hasNamasteSent =
        targetUserId != null && _namastesSentThisSession.contains(targetUserId);

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arrow cue - always there behind, revealed when button fades
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            size: 26,
          ),
          // Namaste button on top (fades away when sent)
          if (!hasNamasteSent)
            NamasteButton(
              onTap: () async {
                if (userId != null) {
                  await _sendNamasteToUser(userId);
                } else if (contact?.userId != null) {
                  await _sendNamasteToContact(contact!);
                }
              },
            ),
        ],
      ),
    );
  }

  void _handleCardTap({
    DmConversation? conversation,
    ContactMatch? contact,
    bool isInvite = false,
  }) {
    if (conversation != null) {
      _openConversation(conversation);
    } else if (contact != null && !isInvite && contact.userId != null) {
      _openProfile(contact.userId!);
    } else if (contact != null && isInvite) {
      _inviteContact(contact);
    }
  }

  Widget _buildCardContent({
    String? userId,
    DmConversation? conversation,
    ContactMatch? contact,
    bool isInvite = false,
    required bool isDark,
  }) {
    // For DM conversations - show user name + last message
    if (conversation != null && conversation.id.startsWith('dm_')) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserNameWidget(conversation.otherUserId),
          SizedBox(height: 2),
          Text(
            _buildLastMessageTextWithoutTime(conversation),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // For group spaces - show space name + last message
    if (conversation != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation.spaceName ?? 'Gram',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            _buildLastMessageTextWithoutTime(conversation),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // For contacts (on app or not)
    if (contact != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isInvite
                  ? (isDark ? AppTheme.textDarkColor : AppTheme.textLightColor)
                  : AppTheme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            contact.displayPhone,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.textSecondaryDarkColor
                  : AppTheme.textSecondaryLightColor,
            ),
          ),
        ],
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildCardAvatar({
    String? userId,
    DmConversation? conversation,
    ContactMatch? contact,
    bool isInvite = false,
  }) {
    // User avatar for DMs and contacts on app
    if (userId != null) {
      return UserAvatar(
        userId: userId,
        size: 44,
        borderRadius: BorderRadius.circular(22),
        loadFromFirestore: true,
      );
    }

    // Space avatar for group conversations
    if (conversation != null && !conversation.id.startsWith('dm_')) {
      return _buildSpaceAvatarCompact(conversation);
    }

    // Initial avatar for contacts not on app
    if (contact != null && isInvite) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Text(
          contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    // Fallback
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Icon(Icons.person, color: AppTheme.primaryColor),
    );
  }

  Widget _buildElevatedAvatar({required Widget child}) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildUnifiedCard({
    String? userId,
    DmConversation? conversation,
    ContactMatch? contact,
    bool isInvite = false,
    required bool isDark,
  }) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    // Determine card content based on what's provided
    final bool isContactNotOnApp = contact != null && isInvite;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        0,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          onTap: () => _handleCardTap(
            conversation: conversation,
            contact: contact,
            isInvite: isInvite,
          ),
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: EdgeInsets.only(left: 20, right: 12),
            child: Row(
              children: [
                // Avatar with elevation
                _buildElevatedAvatar(
                  child: _buildCardAvatar(
                    userId: userId,
                    conversation: conversation,
                    contact: contact,
                    isInvite: isInvite,
                  ),
                ),
                SizedBox(width: 14),

                // Content
                Expanded(
                  child: _buildCardContent(
                    userId: userId,
                    conversation: conversation,
                    contact: contact,
                    isInvite: isInvite,
                    isDark: isDark,
                  ),
                ),

                // Trailing - Time first, then Namaste button (rightmost) with arrow behind
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time for conversations (moved to left of namaste)
                    if (conversation != null) ...[
                      Text(
                        _formatTime(conversation.lastActivity),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                    // Stack for namaste button with arrow behind it
                    if (userId != null || (contact?.userId != null))
                      _buildNamasteWithArrow(
                        userId: userId ?? contact?.userId,
                        contact: contact,
                      ),
                    // Invite button for contacts not on app
                    if (isContactNotOnApp)
                      _buildNamasteIconButton(
                        contact: contact,
                        isInvite: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, int count, bool isDark) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        8,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindFriendsCard(bool isDark) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        0,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          onTap: _isLoadingContacts ? null : () => _syncContacts(),
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: EdgeInsets.only(left: 20, right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Find friends on Aurogram',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                _isLoadingContacts
                    ? const InlineShimmerLoader(size: 20)
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        size: 24,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShowMoreButton(String type, int remaining, bool isDark) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        4,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (type == 'contacts') {
                _contactsNotOnAppLimit += 20;
              } else if (type == 'conversations') {
                _conversationsLimit += 50;
              }
            });
          },
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
                SizedBox(width: 8),
                Text(
                  'Show $remaining more',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCompact(bool isDark) {
    return MessagesEmptyState(isDark: isDark);
  }

  Widget _buildUserSearchResultCard(
      QueryDocumentSnapshot userDoc, bool isDark) {
    final userData = userDoc.data() as Map<String, dynamic>;
    final userName = userData['name'] as String? ??
        userData['nickname'] as String? ??
        'Unknown User';
    final userNickname = userData['nickname'] as String? ?? '';
    final displayPicture = userData['displayPicture'] as String?;
    final userId = userDoc.id;

    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        0,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          onTap: () => _startConversationWithUser(userId, userName),
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: EdgeInsets.only(left: 20, right: 12),
            child: Row(
              children: [
                _buildElevatedAvatar(
                  child: UserAvatar(
                    userId: userId,
                    imageUrl:
                        (displayPicture != null && displayPicture.isNotEmpty)
                            ? displayPicture
                            : null,
                    size: 44,
                    borderRadius: BorderRadius.circular(22),
                    loadFromFirestore:
                        displayPicture == null || displayPicture.isEmpty,
                    nameInitials:
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (userNickname.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          '@$userNickname',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Namaste button for search results too! (with animation)
                _buildNamasteWithArrow(userId: userId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(MessageListItem item, bool isDark) {
    switch (item.type) {
      case MessageListItemType.sectionLabel:
        return _buildSectionLabel(item.title!, item.count!, isDark);
      case MessageListItemType.conversation:
        return _buildUnifiedCard(
          userId: item.conversation!.id.startsWith('dm_')
              ? item.conversation!.otherUserId
              : null,
          conversation: item.conversation,
          isDark: isDark,
        );
      case MessageListItemType.contactOnApp:
        return _buildUnifiedCard(
          userId: item.contactOnApp!.userId,
          contact: item.contactOnApp,
          isDark: isDark,
        );
      case MessageListItemType.contactNotOnApp:
        return _buildUnifiedCard(
          contact: item.contactNotOnApp,
          isInvite: true,
          isDark: isDark,
        );
      case MessageListItemType.userSearchResult:
        return _buildUserSearchResultCard(item.userDoc!, isDark);
      case MessageListItemType.findFriends:
        return _buildFindFriendsCard(isDark);
      case MessageListItemType.showMore:
        return _buildShowMoreButton(item.title!, item.count!, isDark);
      case MessageListItemType.spacer:
        return SizedBox(height: 16);
      case MessageListItemType.emptyState:
        return _buildEmptyStateCompact(isDark);
      case MessageListItemType.messageRequest:
        // Message requests are shown in separate page, not here
        return const SizedBox.shrink();
    }
  }

  Widget _buildSearchResults(List<DmConversation> conversations) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Collect all user IDs already shown
    final shownUserIds = <String>{};
    for (final conv in conversations) {
      if (conv.id.startsWith('dm_')) {
        shownUserIds.add(conv.otherUserId);
      }
    }

    // Filter contacts by search query and exclude already shown
    final filteredContactsOnApp = _contactResult?.onApp
            .where((c) =>
                SearchService.smartMatch(_searchQuery, c.name) &&
                c.userId != null &&
                !shownUserIds.contains(c.userId))
            .toList() ??
        [];

    // Add contact user IDs to shown set
    for (final contact in filteredContactsOnApp) {
      if (contact.userId != null) {
        shownUserIds.add(contact.userId!);
      }
    }

    // Filter user search results to exclude already shown
    final filteredUserResults = _userSearchResults
        .where((user) => !shownUserIds.contains(user.id))
        .toList();

    final filteredContactsNotOnApp = _contactResult?.notOnApp
            .where((c) => SearchService.smartMatch(_searchQuery, c.name))
            .toList() ??
        [];

    final hasConversations = conversations.isNotEmpty;
    final hasUsers = filteredUserResults.isNotEmpty;
    final hasContactsOnApp = filteredContactsOnApp.isNotEmpty;
    final hasContactsNotOnApp = filteredContactsNotOnApp.isNotEmpty;
    final hasResults =
        hasConversations || hasUsers || hasContactsOnApp || hasContactsNotOnApp;

    final metricsKey = [
      _searchQuery.trim(),
      conversations.length,
      filteredUserResults.length,
      filteredContactsOnApp.length,
      filteredContactsNotOnApp.length,
      _isSearchingUsers,
    ].join('|');
    if (_lastSearchMetricsKey != metricsKey) {
      _lastSearchMetricsKey = metricsKey;
      AppLogger.i('Messages search metrics', category: LogCategory.ui, data: {
        'query': _searchQuery.trim(),
        'conversations': conversations.length,
        'user_results': filteredUserResults.length,
        'contacts_on_app': filteredContactsOnApp.length,
        'contacts_not_on_app': filteredContactsNotOnApp.length,
        'is_searching_users': _isSearchingUsers,
      });
    }

    if (_isSearchingUsers && !hasResults) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: List.generate(4, (_) => SkeletonListItem()),
        ),
      );
    }

    if (!hasResults) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 40,
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No results found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Build items list
    final items = <MessageListItem>[];

    if (hasConversations) {
      items.add(
          MessageListItem.sectionLabel('conversations', conversations.length));
      for (final conv in conversations) {
        items.add(MessageListItem.conversation(conv));
      }
    }

    if (hasUsers) {
      items.add(MessageListItem.sectionLabel(
          'start new chat', filteredUserResults.length));
      for (final userDoc in filteredUserResults) {
        items.add(MessageListItem.userSearchResult(userDoc));
      }
    }

    if (hasContactsOnApp) {
      items.add(MessageListItem.sectionLabel(
          'on aurogram', filteredContactsOnApp.length));
      for (final contact in filteredContactsOnApp) {
        items.add(MessageListItem.contactOnApp(contact));
      }
    }

    if (hasContactsNotOnApp) {
      items.add(MessageListItem.sectionLabel(
          'contacts', filteredContactsNotOnApp.length));
      for (final contact in filteredContactsNotOnApp.take(10)) {
        items.add(MessageListItem.contactNotOnApp(contact));
      }
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding:
          EdgeInsets.only(top: AppHeaderStyle.contentTopPadding, bottom: 210),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildListItem(items[index], isDark),
    );
  }

  Widget _buildAllSections(List<DmConversation> conversations) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter out pending requests (they're shown in separate page)
    final acceptedConversations = conversations.where((c) => 
      c.status != 'pending' && c.status != 'declined'
    ).toList();

    // Filter contacts to exclude those with active chats (no duplicates!)
    final contactsOnApp = _contactResult?.onApp
            .where(
                (c) => c.userId != null && !_activeUserIds.contains(c.userId))
            .toList() ??
        [];
    final contactsNotOnApp = _contactResult?.notOnApp ?? [];

    final hasChats = acceptedConversations.isNotEmpty;
    final hasContactsOnApp = contactsOnApp.isNotEmpty;
    final hasContactsNotOnApp = contactsNotOnApp.isNotEmpty;
    final hasNoContent = !hasChats && !hasContactsOnApp && !hasContactsNotOnApp;

    // Build items list for ListView.builder
    final items = <MessageListItem>[];

    // Add chats section
    if (hasChats) {
      for (final conv in acceptedConversations.take(_conversationsLimit)) {
        items.add(MessageListItem.conversation(conv));
      }
      if (acceptedConversations.length > _conversationsLimit) {
        items.add(MessageListItem.showMore(
            'conversations', acceptedConversations.length - _conversationsLimit));
      }
      items.add(MessageListItem.spacer());
    }

    // Show find friends prompt if no contacts synced
    if (_contactResult == null && !_hasRequestedContactPermission) {
      items.add(MessageListItem.findFriends());
    } else {
      // Contacts on app section
      if (hasContactsOnApp) {
        items.add(
            MessageListItem.sectionLabel('on aurogram', contactsOnApp.length));
        for (final contact in contactsOnApp) {
          items.add(MessageListItem.contactOnApp(contact));
        }
        items.add(MessageListItem.spacer());
      }

      // Contacts not on app section
      if (hasContactsNotOnApp) {
        items.add(
            MessageListItem.sectionLabel('contacts', contactsNotOnApp.length));
        for (final contact in contactsNotOnApp.take(_contactsNotOnAppLimit)) {
          items.add(MessageListItem.contactNotOnApp(contact));
        }
        if (contactsNotOnApp.length > _contactsNotOnAppLimit) {
          items.add(MessageListItem.showMore(
              'contacts', contactsNotOnApp.length - _contactsNotOnAppLimit));
        }
      }
    }

    // Empty state
    if (hasNoContent && _contactResult != null) {
      items.add(MessageListItem.emptyState());
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding:
          EdgeInsets.only(top: AppHeaderStyle.contentTopPadding, bottom: 220),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildListItem(items[index], isDark),
    );
  }

  Widget _buildEmptyDetailState(bool isDark) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose from your existing conversations\nor start a new one',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filter out AI conversations from the list
  List<DmConversation> _filterAiConversations(
      List<DmConversation> conversations) {
    final beforeCount = conversations.length;
    final filtered = conversations.where((conversation) {
      // Filter out AI conversations
      final isAiConversation = conversation.otherUserId == HOLYCOW_USER_ID ||
          conversation.id.startsWith('ai_chat_') ||
          conversation.id.contains('holycow_system_user');

      if (isAiConversation) {
        AppLogger.d('🚫 Filtered out AI conversation',
            category: LogCategory.ui,
            data: {
              'id': conversation.id,
              'otherUserId': conversation.otherUserId,
            });
      }

      return !isAiConversation;
    }).toList();

    if (beforeCount != filtered.length) {
      AppLogger.d('🔍 AI Filter applied', category: LogCategory.ui, data: {
        'before': beforeCount,
        'after': filtered.length,
        'removed': beforeCount - filtered.length,
      });
    }

    return filtered;
  }

  Widget _buildMessagesList() {
    // Smooth crossfade transition between skeleton and content
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _isRefreshing
          ? MessageSkeletons(key: const ValueKey('skeleton'))
          : _buildActualContent(key: const ValueKey('content')),
    );
  }

  /// Build desktop master-detail layout with conversation list on left and chat on right
  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Row(
      children: [
        // Left panel - Conversation list (fixed width)
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkColor : Colors.white,
              border: Border(
                right: BorderSide(color: dividerColor, width: 1),
              ),
            ),
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppTheme.primaryColor,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      AppHeaderStyle.buildWideLayoutHeaderSliver(
                        context,
                        title: 'Messages',
                        trailing: _isRefreshing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor),
                                ),
                              )
                            : null,
                      ),
                      SliverToBoxAdapter(child: _buildMessagesList()),
                      SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: MessagesSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onSearchChanged: _onSearchChanged,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right panel - Chat view (fills remaining space)
        Expanded(
          child: _selectedConversationId != null
              ? EmbeddedChatView(
                  spaceId: _selectedConversationId!,
                  space: _selectedSpace,
                  otherUserId: _selectedOtherUserId,
                )
              : _buildEmptyDetailState(isDark),
        ),
      ],
    );
  }

  Widget _buildActualContent({Key? key}) {
    return StreamBuilder<List<DmConversation>>(
      key: key,
      stream: _conversationsStream,
      builder: (context, snapshot) {
        // Log stream state for debugging
        AppLogger.d('📱 Messages StreamBuilder state',
            category: LogCategory.ui,
            data: {
              'hasData': snapshot.hasData,
              'hasError': snapshot.hasError,
              'connectionState': snapshot.connectionState.toString(),
              'dataCount': snapshot.data?.length ?? 0,
              'cachedCount': _cachedConversations.length,
            });

        if (snapshot.hasError) {
          AppLogger.e('🔥 StreamBuilder ERROR: ${snapshot.error}',
              category: LogCategory.ui, error: snapshot.error);

          String errorMessage = 'Error loading messages';
          String errorDetails = 'Pull to refresh or try again';

          final errorText = snapshot.error.toString().toLowerCase();
          if (errorText.contains('timeout') ||
              errorText.contains('connection')) {
            errorMessage = 'Connection timeout';
            errorDetails =
                'Please check your internet connection and try again';
          } else if (errorText.contains('permission') ||
              errorText.contains('denied')) {
            errorMessage = 'Permission denied';
            errorDetails = 'Please check your account permissions';
          } else if (errorText.contains('index') ||
              errorText.contains('requires an index')) {
            errorMessage = 'Database index missing';
            errorDetails = 'Please contact support or try again later';
            AppLogger.e('🔥 Missing Firestore index - deploy indexes required',
                category: LogCategory.ui,
                data: {'error': snapshot.error.toString()});
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 64, color: Colors.orange[400]),
                SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                      ),
                ),
                SizedBox(height: 8),
                Text(
                  errorDetails,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isRefreshing ? null : _handleRefresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: _isRefreshing
                      ? PulsingDots(color: Colors.white, size: 6)
                      : Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        // Show loading state only on initial load (waiting + no data + no cache)
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            _cachedConversations.isEmpty) {
          AppLogger.d('⏳ Messages: Showing loading state (initial load)',
              category: LogCategory.ui);
          return MessageSkeletons(key: const ValueKey('loading'));
        }

        // Filter out AI conversations and pending requests first
        var conversations = snapshot.data ?? _cachedConversations;
        final hadDataBefore = snapshot.hasData;

        if (snapshot.hasData) {
          _cachedConversations = snapshot.data ?? [];
          AppLogger.d('✅ Messages: Updated cached conversations',
              category: LogCategory.ui,
              data: {
                'count': _cachedConversations.length,
                'rawData': snapshot.data?.length ?? 0,
              });
        }

        final beforeFilterCount = conversations.length;
        conversations = _filterAiConversations(conversations);
        // Filter out pending requests (they're shown in separate page)
        conversations = conversations.where((c) => 
          c.status != 'pending' || c.requestedBy == _currentUser?.uid
        ).toList();
        _updateChatCount(conversations.length);

        AppLogger.d('📱 Messages: Final conversations count',
            category: LogCategory.ui,
            data: {
              'afterFilter': conversations.length,
              'beforeFilter': beforeFilterCount,
              'hadData': hadDataBefore,
              'connectionState': snapshot.connectionState.toString(),
            });

        // Update active user IDs for deduplication
        _activeUserIds = <String>{};
        for (final conv in conversations) {
          if (conv.id.startsWith('dm_')) {
            _activeUserIds.add(conv.otherUserId);
          }
        }

        // Batch prefetch user names (non-blocking)
        _prefetchUserNames(conversations);

        // If no search query, show all sections
        if (_searchQuery.trim().isEmpty) {
          return _buildAllSections(conversations);
        }

        // Use FutureBuilder for async search filtering
        return FutureBuilder<List<DmConversation>>(
          future: _filterBySearch(conversations, _searchQuery),
          builder: (context, filterSnapshot) {
            if (filterSnapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: List.generate(4, (_) => SkeletonListItem()),
              );
            }

            final filteredConversations = filterSnapshot.data ?? conversations;
            return _buildSearchResults(filteredConversations);
          },
        );
      },
    );
  }

  /// Batch prefetch user names for all conversations
  Future<void> _prefetchUserNames(List<DmConversation> conversations) async {
    final unknownUserIds = conversations
        .where((c) => c.id.startsWith('dm_'))
        .map((c) => c.otherUserId)
        .where((id) => !_userNameCache.containsKey(id))
        .toSet()
        .toList();

    if (unknownUserIds.isEmpty) return;

    // Batch query in chunks of 10 (Firestore whereIn limit)
    for (var i = 0; i < unknownUserIds.length; i += 10) {
      final chunk = unknownUserIds.skip(i).take(10).toList();
      try {
        final docs = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in docs.docs) {
          final data = doc.data();
          _userNameCache[doc.id] =
              data['name'] as String? ?? data['nickname'] as String? ?? doc.id;
        }
      } catch (e) {
        AppLogger.w('Error batch fetching user names',
            category: LogCategory.ui, data: {'error': e.toString()});
      }
    }
  }

  /// Filter conversations based on search query (async version that fetches user names)
  /// Uses smart matching for better search results (handles spaces, word order, etc.)
  Future<List<DmConversation>> _filterBySearch(
      List<DmConversation> conversations, String query) async {
    if (query.trim().isEmpty) {
      return conversations;
    }

    final List<DmConversation> filtered = [];

    // Process conversations in parallel for better performance
    final List<Future<bool>> matchFutures =
        conversations.map((conversation) async {
      // For space conversations, search by space name using smart matching
      if (conversation.spaceName != null) {
        if (SearchService.smartMatch(query, conversation.spaceName!)) {
          return true;
        }
      } else {
        // For DM conversations, fetch the actual user name and search by it using smart matching
        final userName = await _getUserName(conversation.otherUserId);
        if (SearchService.smartMatch(query, userName)) {
          return true;
        }
      }

      // Search in last message content using smart matching
      if (conversation.lastMessageContent != null &&
          SearchService.smartMatch(query, conversation.lastMessageContent!)) {
        return true;
      }

      return false;
    }).toList();

    // Wait for all matches to be determined
    final matches = await Future.wait(matchFutures);

    // Build filtered list based on matches
    for (int i = 0; i < conversations.length; i++) {
      if (matches[i]) {
        filtered.add(conversations[i]);
      }
    }

    return filtered;
  }

  void _onSearchChanged(String query) {
    if (query == _searchQuery) return;
    setState(() {
      _searchQuery = query;
    });

    // Cancel previous debounce timer
    _searchDebounceTimer?.cancel();

    final trimmedQuery = query.trim();
    AppLogger.i('Messages search query changed',
        category: LogCategory.ui,
        data: {
          'query': trimmedQuery,
          'length': trimmedQuery.length,
        });

    // Search users via Firestore when query is not empty (with debounce)
    if (trimmedQuery.length >= _minSearchLength) {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _searchQuery == query) {
          _searchUsers(trimmedQuery);
        }
      });
    } else {
      if (_userSearchResults.isEmpty && !_isSearchingUsers) return;
      setState(() {
        _userSearchResults = [];
        _isSearchingUsers = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < _minSearchLength) {
      if (_userSearchResults.isEmpty && !_isSearchingUsers) return;
      setState(() {
        _userSearchResults = [];
        _isSearchingUsers = false;
      });
      return;
    }

    // Don't search if query changed while we were waiting
    if (_searchQuery != query) {
      return;
    }

    if (!_isSearchingUsers) {
      setState(() {
        _isSearchingUsers = true;
      });
    }

    try {
      final stopwatch = Stopwatch()..start();
      // Start user search immediately
      final results = await _searchService.searchUsers(query, limit: 50);

      // Verify query hasn't changed during async operation
      if (!mounted || _searchQuery != query) {
        return;
      }

      setState(() {
        if (!_areSameUserResults(_userSearchResults, results)) {
          _userSearchResults = results;
        }
        _isSearchingUsers = false;
      });
      stopwatch.stop();
      AppLogger.i('Messages user search completed',
          category: LogCategory.ui,
          data: {
            'query': query,
            'results': results.length,
            'duration_ms': stopwatch.elapsedMilliseconds,
          });
    } catch (e) {
      AppLogger.e('Error searching users in Firestore',
          category: LogCategory.ui, error: e);

      if (mounted && _searchQuery == query) {
        setState(() {
          _userSearchResults = [];
          _isSearchingUsers = false;
        });
      }
    }
  }

  Future<void> _startConversationWithUser(
      String userId, String userName) async {
    if (_currentUser == null) {
      showLoginBottomSheet(context);
      return;
    }

    try {
      // Fetch actual user data to get the correct name
      String actualUserName = userName;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            actualUserName = userData['name'] as String? ??
                userData['nickname'] as String? ??
                userName;
          }
        }
      } catch (e) {
        AppLogger.w('Error fetching user data, using provided name',
            category: LogCategory.ui, data: {'error': e.toString()});
      }

      // Create or get existing conversation
      final conversationId = await _chatService.createDirectMessage(userId);

      if (mounted) {
        // Clear search
        _searchController.clear();
        _onSearchChanged('');
        _searchFocusNode.unfocus();

        final space = Space(
          id: conversationId,
          name: actualUserName,
          searchName: 'dm_$userId',
          description: 'Direct message conversation',
          spaceType: SpaceType.private,
          limitedVisibility: false,
        );

        // On wide layout (desktop / iPad landscape), show chat inline
        if (Responsive.isWideLayout(context)) {
          setState(() {
            _selectedConversationId = conversationId;
            _selectedSpace = space;
            _selectedOtherUserId = userId;
          });
        } else {
          // On mobile, push the chat screen
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => SpaceChatScreen(
                spaceId: conversationId,
                space: space,
                otherUserId: userId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Error'),
            content: Text('Failed to create conversation: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isWideLayout = Responsive.isWideLayout(context);
    // Hide header in wide layout (sidebar handles navigation)
    final bool hideHeader = isWideLayout;

    if (_currentUser == null) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: hideHeader
            ? null
            : AppHeaderStyle.buildStandardAppBar(
                context: context,
                title: "messages",
              ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.message_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
              SizedBox(height: 16),
              Text(
                'Please log in to view messages',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => showLoginBottomSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: Text('Log In'),
              ),
            ],
          ),
        ),
      );
    }

    final showSearch = _selectedTab == _MessagesTab.chats && !isWideLayout;
    if (isWideLayout && _selectedTab == _MessagesTab.chats) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildTabChips(),
            ),
            Expanded(child: _buildDesktopLayout()),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus();
        },
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                AppHeaderStyle.buildStandardHeader(
                  context: context,
                  title: "messages",
                  actionButton: _buildAnonymousButton(),
                  leadingWidget: const SizedBox.shrink(),
                  showSearchField: false,
                  backgroundStyle: HeaderBackgroundStyle.gradient,
                  isRefreshing: _isRefreshing,
                ),
                if (_selectedTab == _MessagesTab.chats)
                  CupertinoSliverRefreshControl(
                    onRefresh: _handleRefresh,
                    builder: (context, refreshState, pulledExtent,
                        refreshTriggerPullDistance, refreshIndicatorExtent) {
                      return const SizedBox.shrink();
                    },
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: _buildTabChips(),
                  ),
                ),
                if (_selectedTab == _MessagesTab.chats) ...[
                  SliverToBoxAdapter(child: _buildMessagesList()),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ] else ...[
                  _buildMessageRequestsSliver(),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ],
            ),
            if (showSearch)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: MessagesSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onSearchChanged: _onSearchChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChips() {
    return StreamBuilder<List<DmConversation>>(
      stream: _chatService.getUserDmConversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? [];
        final pendingCount = conversations.where((c) =>
          c.status == 'pending' &&
          c.requestedBy != _currentUser?.uid
        ).length;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardColor =
            isDark ? Theme.of(context).colorScheme.surface : Colors.white;
        return Row(
          children: [
            Expanded(
              child: _buildTabChip(
                label: 'Chats',
                count: _chatCount,
                selected: _selectedTab == _MessagesTab.chats,
                onSelected: () => _setTab(_MessagesTab.chats),
                cardColor: cardColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTabChip(
                label: 'Requests',
                count: pendingCount,
                selected: _selectedTab == _MessagesTab.requests,
                onSelected: () => _setTab(_MessagesTab.requests),
                cardColor: cardColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onSelected,
    required Color cardColor,
  }) {
    final textColor =
        selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor;
    return GestureDetector(
      onTap: onSelected,
      child: Material(
        color: selected ? cardColor : Colors.transparent,
        elevation: selected ? 0.8 : 0.0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnonymousButton() {
    return FutureBuilder<bool>(
      future: AnonymousMessageSettingsService().isEnabled(),
      builder: (context, enabledSnapshot) {
        final isEnabled = enabledSnapshot.data ?? true;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return StreamBuilder<QuerySnapshot>(
          stream: _currentUser == null
              ? null
              : FirebaseFirestore.instance
                  .collection('anonymousMessages')
                  .where('recipientId', isEqualTo: _currentUser!.uid)
                  .snapshots(),
          builder: (context, snapshot) {
            final anonymousCount = snapshot.data?.docs.length ?? 0;
            
            return GestureDetector(
              onTap: () {
                if (isEnabled) {
                  // Navigate to anonymous messages page
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => const SecretMessagesGetLinkScreen(),
                    ),
                  );
                } else {
                  // Show settings prompt
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Anonymous messages are disabled. Enable them in settings.'),
                      backgroundColor: AppTheme.primaryColor,
                      action: SnackBarAction(
                        label: 'Settings',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => const UserSettingsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Stack(
                  children: [
                    Icon(
                      Icons.visibility_off,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    if (anonymousCount > 0 && isEnabled)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppTheme.scaffoldDarkColor : Colors.white,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            anonymousCount > 9 ? '9+' : '$anonymousCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageRequestsButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<DmConversation>>(
      stream: _chatService.getUserDmConversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? [];
        final pendingCount = conversations.where((c) =>
          c.status == 'pending' &&
          c.requestedBy != _currentUser?.uid
        ).length;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => const MessageRequestsPage(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Stack(
              children: [
                Icon(
                  Icons.mail_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.scaffoldDarkColor : Colors.white,
                          width: 2,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        pendingCount > 9 ? '9+' : '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setTab(_MessagesTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
    });
  }

  Future<String> _fetchAnonymousShareLink() async {
    final slug = await _anonymousService.getOrCreateSlug();
    return _anonymousService.buildShareLink(slug);
  }

  Future<void> _loadCurrentUserPhoto() async {
    final userId = _currentUser?.uid;
    if (userId == null) return;
    try {
      final doc = await _userService.getUser(userId);
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>?;
      final photo = data?['displayPicture'] as String? ??
          data?['profilePictureUrl'] as String?;
      final heading = data?['anonymousPromptHeading'] as String?;
      final subheading = data?['anonymousPromptSubheading'] as String?;
      setState(() {
        if (photo != null && photo.isNotEmpty) {
          _currentUserPhotoUrl = photo;
        }
        if (heading != null && heading.trim().isNotEmpty) {
          _anonymousHeading = heading.trim();
        }
        if (subheading != null && subheading.trim().isNotEmpty) {
          _anonymousSubheading = subheading.trim();
        }
        if (!_anonymousHeadingFocusNode.hasFocus) {
          _anonymousHeadingController.text = _anonymousHeading;
        }
        if (!_anonymousSubheadingFocusNode.hasFocus) {
          _anonymousSubheadingController.text = _anonymousSubheading;
        }
      });
    } catch (e) {
      AppLogger.w('Failed to load current user photo',
          category: LogCategory.database, data: {'error': e.toString()});
    }
  }

  Future<void> _shareAnonymousLinkCard(String link) async {
    final card = AnonymousLinkShareCard(
      shareLink: link,
      avatarUrl: _currentUserPhotoUrl ?? _currentUser?.photoURL,
      heading: _anonymousHeading,
      subheading: _anonymousSubheading,
    );
    await ShareMedia.shareWidgetToInstagramStory(
      context: context,
      card: card,
      filePrefix: 'anonymous_link',
      shareUrl: link,
      logLabel: 'anonymous_link_share',
    );
  }

  Future<void> _copyAnonymousLink(String link, {bool showToast = true}) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted || !showToast) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _handlePromptFocusChange() {
    if (_anonymousHeadingFocusNode.hasFocus ||
        _anonymousSubheadingFocusNode.hasFocus) {
      return;
    }
    _saveAnonymousPrompt();
  }

  Future<void> _saveAnonymousPrompt() async {
    final userId = _currentUser?.uid;
    if (userId == null) return;
    final heading = _anonymousHeadingController.text.trim();
    final subheading = _anonymousSubheadingController.text.trim();
    final nextHeading = heading.isEmpty ? _defaultAnonymousHeading : heading;
    final nextSubheading =
        subheading.isEmpty ? _defaultAnonymousSubheading : subheading;
    setState(() {
      _anonymousHeading = nextHeading;
      _anonymousSubheading = nextSubheading;
      _anonymousHeadingController.text = nextHeading;
      _anonymousSubheadingController.text = nextSubheading;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'anonymousPromptHeading': nextHeading,
        'anonymousPromptSubheading': nextSubheading,
      });
    } catch (e) {
      AppLogger.w('Failed to update anonymous prompt',
          category: LogCategory.database, data: {'error': e.toString()});
    }
  }

  SliverToBoxAdapter _buildAnonymousShareCard() {
    if (_currentUser == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: FutureBuilder<bool>(
        future: AnonymousMessageSettingsService().isEnabled(),
        builder: (context, enabledSnapshot) {
          if (enabledSnapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final isEnabled = enabledSnapshot.data ?? true;

          // When disabled, don't show the card - let _buildAnonymousMessagesSliver handle the disabled message
          if (!isEnabled) {
            return const SizedBox.shrink();
          }

          return _buildAnonymousShareCardContent();
        },
      ),
    );
  }

  Widget _buildAnonymousShareCardContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: FutureBuilder<String>(
          future: _anonymousShareLinkFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return TransparentToolbox.buildCard(
                context: context,
                padding: const EdgeInsets.all(16),
                child: const SizedBox(
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return TransparentToolbox.buildCard(
                context: context,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share your link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Could not load your link. Tap to try again.',
                      style: TextStyle(color: AppTheme.textSecondaryColor),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _anonymousShareLinkFuture =
                              _fetchAnonymousShareLink();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                      child: Text(
                        'Retry',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
              );
            }

            final link = snapshot.data!;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnonymousShareCardPreview(
                    theme: const _AnonymousSharePreviewTheme(
                        accent: Color(0xFF6A2BD9)),
                    avatarUrl: _currentUserPhotoUrl ?? _currentUser?.photoURL,
                    headingController: _anonymousHeadingController,
                    subheadingController: _anonymousSubheadingController,
                    headingFocusNode: _anonymousHeadingFocusNode,
                    subheadingFocusNode: _anonymousSubheadingFocusNode,
                    heading: _anonymousHeading,
                    subheading: _anonymousSubheading,
                    onSave: _saveAnonymousPrompt,
                  ),
                  const SizedBox(height: 10),
                  TransparentToolbox.buildCard(
                    context: context,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Step 1',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _copyAnonymousLink(link),
                                      icon: const Icon(Icons.link_rounded,
                                          size: 16),
                                      label: const Text('Copy link'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryColor,
                                        side: BorderSide(
                                          color:
                                              AppTheme.primaryColor.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 64,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              color: AppTheme.textSecondaryColor
                                  .withValues(alpha: 0.3),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Step 2',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _shareAnonymousLinkCard(link),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/icons/instagram.svg',
                                            width: 16,
                                            height: 16,
                                            colorFilter: const ColorFilter.mode(
                                                Colors.white, BlendMode.srcIn),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('Share'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a Link sticker to collect replies.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
    );
  }

  SliverToBoxAdapter _buildAnonymousMessagesSliver() {
    return SliverToBoxAdapter(
      child: FutureBuilder<bool>(
        future: AnonymousMessageSettingsService().isEnabled(),
        builder: (context, enabledSnapshot) {
          if (enabledSnapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final isEnabled = enabledSnapshot.data ?? true;

          if (!isEnabled) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 48,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Anonymous messages are disabled',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enable anonymous messages in Settings > Privacy to view messages.',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => const UserSettingsPage(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.primaryColor),
                    ),
                    child: Text(
                      'Open Settings',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildAnonymousMessagesSliverContent();
        },
      ),
    );
  }

  /// Compact list row for Anonymous tab (NGL-style: icon, preview, time, chevron).
  Widget _buildAnonymousMessageListRow({
    required String messageId,
    required String message,
    required String timeLabel,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    const int previewMaxChars = 50;
    final preview = message.length <= previewMaxChars
        ? message
        : '${message.substring(0, previewMaxChars)}...';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        0,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          onTap: onTap,
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.mail_outline,
                    size: 26,
                    color: AppTheme.primaryColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondaryColor,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAnonymousMessageDetail({
    required String messageId,
    required String message,
    required String timeLabel,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => AnonymousMessageDetailPage(
          heading: _anonymousHeading,
          message: message,
          timeLabel: timeLabel,
          onShare: () => _shareAnonymousMessageToStory(message),
          onDelete: () async {
            await _deleteAnonymousMessage(messageId);
            if (!mounted) return;
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _deleteAnonymousMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('anonymousMessages')
          .doc(messageId)
          .delete();
    } catch (e) {
      _anonymousService.logError('Failed to delete anonymous message', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete message')),
      );
    }
  }

  /// Share message card to Instagram story (like prompt card), with user's link.
  Future<void> _shareAnonymousMessageToStory(String text) async {
    try {
      final slug = await _anonymousService.getOrCreateSlug();
      final shareLink = _anonymousService.buildShareLink(slug);
      final card = AnonymousMessageStoryCard(
        heading: _anonymousHeading,
        message: text,
      );
      await ShareMedia.shareWidgetToInstagramStory(
        context: context,
        card: card,
        filePrefix: 'anonymous_message_story',
        shareUrl: shareLink,
        logLabel: 'anonymous_message_story_share',
      );
    } catch (e) {
      _anonymousService.logError('Failed to share to story', e);
    }
  }

  Widget _buildAnonymousMessagesSliverContent() {
    if (_currentUser == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: () => showLoginBottomSheet(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: const Text('Sign in to view'),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('anonymousMessages')
            .where('recipientId', isEqualTo: _currentUser!.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn\'t load messages.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pull to refresh to try again.',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No messages yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share your link to get your first one.',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: docs.map<Widget>((doc) {
              final data = doc.data();
              final text = data['text'] as String? ?? '';
              final timestamp = data['createdAt'];
              final dateTime =
                  timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
              final timeLabel = TimeDisplay.getCompactTimestamp(dateTime);
              return _buildAnonymousMessageListRow(
                messageId: doc.id,
                message: text,
                timeLabel: timeLabel,
                onTap: () => _openAnonymousMessageDetail(
                  messageId: doc.id,
                  message: text,
                  timeLabel: timeLabel,
                ),
              );
            }).toList(),
          );
        },
    );
  }

  SliverToBoxAdapter _buildMessageRequestsSliver() {
    if (_currentUser == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please log in to view message requests',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: StreamBuilder<List<DmConversation>>(
        stream: _chatService.getUserDmConversations(),
        builder: (context, snapshot) {
          // Show loading only on initial load (waiting + no data + no cache)
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              _cachedConversations.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading message requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Use cached conversations if stream hasn't emitted yet
          final conversations = snapshot.data ?? _cachedConversations;
          final pendingRequests = conversations.where((c) =>
            c.status == 'pending' &&
            c.requestedBy != _currentUser?.uid
          ).toList();

          if (pendingRequests.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No message requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When someone wants to message you, their request will appear here.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Column(
            children: pendingRequests.map((request) => _buildRequestCardInline(request, isDark)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildRequestCardInline(DmConversation request, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatar(
                  userId: request.otherUserId,
                  size: 56,
                  loadFromFirestore: true,
                  nameInitials: request.otherUserId.isNotEmpty
                      ? request.otherUserId[0].toUpperCase()
                      : 'U',
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 4),
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
          if (request.lastMessageContent != null &&
              request.lastMessageContent!.isNotEmpty) ...[
            Divider(
              height: 1,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineRequestInline(request.id),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.errorColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptRequestInline(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Future<void> _acceptRequestInline(DmConversation request) async {
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

  Future<void> _declineRequestInline(String conversationId) async {
    final success = await _chatService.declineMessageRequest(conversationId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message request declined'),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to decline request'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
