import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/services/chat/chat_notification_service.dart';
import 'package:aurogram/services/namaste_service.dart';
import 'package:aurogram/services/call_service.dart';
import 'package:aurogram/widgets/call/active_call_banner.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:get_it/get_it.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/user_service.dart';

// Extracted widgets
import 'widgets/space_chat_header.dart';
import 'widgets/space_chat_input.dart';
import 'widgets/chat_message_tiles.dart';
import 'widgets/media_gallery_page.dart';
import 'package:aurogram/widgets/chat/chat_picker_sheet.dart';
import 'package:aurogram/widgets/chat/message_search_sheet.dart';
import 'package:aurogram/widgets/chat/conversation_options_sheet.dart';

class SpaceChatScreen extends StatefulWidget {
  final String spaceId;
  final Space? space;
  final String? otherUserId;

  /// Optional initial text for the message field (e.g. "Replying to your story").
  final String? initialMessage;

  const SpaceChatScreen({
    super.key,
    required this.spaceId,
    this.space,
    this.otherUserId,
    this.initialMessage,
  });

  @override
  SpaceChatScreenState createState() => SpaceChatScreenState();
}

class SpaceChatScreenState extends State<SpaceChatScreen> {
  final SpaceChatService _chatService = SpaceChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Cache for sender names
  static final Map<String, String> _senderNameCache = {};

  // State
  String? _displayName;
  bool _isLoadingName = false;
  final List<ChatMessage> _sendingMessages = [];
  bool _isAtBottom = true;
  final bool _isConnected = true;
  List<TypingUser> _typingUsers = [];
  bool _isTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _typingSubscription;
  ChatMessage? _replyingTo;
  final Map<String, ChatMessage> _repliedMessagesCache = {};
  List<ChatMessage> _allMessages = [];
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  StreamSubscription? _onlineStatusSubscription;
  bool _namasteSentThisSession = false;

  /// Instagram-style: swipe left to reveal timestamps on the right. 0 = hidden, 56 = visible.
  double _timestampRevealOffset = 0.0;
  static const double _kTimestampRevealStripWidth = 80.0;
  bool _isDraggingReveal = false;
  double _totalDragDx = 0;
  double _totalDragDy = 0;

  // Conversation status tracking (for message requests)
  String? _conversationStatus; // 'pending', 'accepted', 'declined', or null
  String? _requestedBy; // Who initiated the conversation
  StreamSubscription? _conversationStatusSubscription;

  bool get _isDMConversation => widget.spaceId.startsWith('dm_');
  bool get _isPendingRequest => 
      _isDMConversation && 
      _conversationStatus == 'pending' && 
      _requestedBy != _currentUser?.uid;

  @override
  void initState() {
    super.initState();
    ChatNotificationService.setActiveChat(widget.spaceId);
    _scrollController.addListener(_onScroll);
    _textFieldFocusNode.addListener(_onFocusChange);

    if (_isDMConversation && widget.otherUserId != null) {
      _loadDisplayName();
      _listenToOnlineStatus();
    } else {
      _displayName = widget.space?.name ?? 'Chat';
    }

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _messageController.text = widget.initialMessage!;
          setState(() {});
        }
      });
    }

    // Subscribe to typing indicators
    _listenToTypingUsers();

    // Listen to conversation status (for message requests)
    if (_isDMConversation) {
      _listenToConversationStatus();
    }
  }

  void _listenToConversationStatus() {
    _conversationStatusSubscription = FirebaseFirestore.instance
        .collection('dmConversations')
        .doc(widget.spaceId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        setState(() {
          _conversationStatus = data?['status'] as String?;
          _requestedBy = data?['requestedBy'] as String?;
        });
      }
    });
  }

  void _listenToTypingUsers() {
    _typingSubscription = _chatService.getTypingUsers(widget.spaceId).listen(
      (users) {
        if (mounted) {
          setState(() => _typingUsers = users);
        }
      },
      onError: (e) {
        // Silently ignore typing indicator errors
        AppLogger.w('Error listening to typing users',
            category: LogCategory.ui, data: {'error': e.toString()});
      },
    );
  }

  void _onFocusChange() {
    if (_textFieldFocusNode.hasFocus) {
      _forceScrollToBottom();
      for (int delay in [50, 150, 300, 500]) {
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted) _forceScrollToBottom();
        });
      }
    }
  }

  void _listenToOnlineStatus() {
    if (widget.otherUserId == null) return;
    _onlineStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        setState(() {
          _isOtherUserOnline = data?['isOnline'] as bool? ?? false;
          _otherUserLastSeen = (data?['lastSeen'] as Timestamp?)?.toDate();
        });
      }
    });
  }

  Future<void> _loadDisplayName() async {
    if (widget.otherUserId == null) {
      _displayName = widget.space?.name ?? 'Chat';
      return;
    }

    setState(() => _isLoadingName = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId!)
          .get();

      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        final name = userData?['name'] as String? ??
            userData?['nickname'] as String? ??
            widget.space?.name ??
            'Chat';
        setState(() {
          _displayName = name;
          _isLoadingName = false;
        });
        return;
      }
    } catch (e) {
      AppLogger.w('Error loading display name',
          category: LogCategory.ui, data: {'error': e.toString()});
    }

    if (mounted) {
      setState(() {
        _displayName = widget.space?.name ?? 'Chat';
        _isLoadingName = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final wasAtBottom = _isAtBottom;
      _isAtBottom = _scrollController.offset <= 100;
      if (wasAtBottom != _isAtBottom) setState(() {});
    }
  }

  void _onTextChanged(String text) {
    if (text.trim().isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
      // Update typing status in Firestore
      _chatService.setTyping(widget.spaceId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isTyping) {
        setState(() => _isTyping = false);
        // Clear typing status in Firestore
        _chatService.setTyping(widget.spaceId, false);
      }
    });
  }

  @override
  void dispose() {
    ChatNotificationService.clearActiveChat();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _onlineStatusSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    // Clear typing status when leaving chat
    _chatService.setTyping(widget.spaceId, false);
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottomInstant() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _forceScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final replyToId = _replyingTo?.id;
    final tempId = 'sending_${DateTime.now().millisecondsSinceEpoch}';
    final sendingMessage = ChatMessage(
      id: tempId,
      spaceId: widget.spaceId,
      senderId: _currentUser?.uid ?? '',
      senderName: await _getUserName(_currentUser?.uid ?? ''),
      senderAvatar: null,
      content: message,
      messageType: 'text',
      replyTo: replyToId,
      reactions: {},
      readBy: [],
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _messageController.clear();
    setState(() {
      _sendingMessages.add(sendingMessage);
      _replyingTo = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAtBottom) _scrollToBottomInstant();
    });

    try {
      // Extract mentioned user IDs from message
      List<String>? mentionedUserIds;
      if (message.contains('@')) {
        try {
          final users = await _chatService.getMentionableUsers(widget.spaceId);
          mentionedUserIds = _extractMentionedUserIds(message, users);
        } catch (e) {
          // Ignore mention extraction errors
        }
      }

      await _chatService.sendTextMessage(widget.spaceId, message,
          replyTo: replyToId, mentionedUserIds: mentionedUserIds);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAtBottom) _scrollToBottomInstant();
      });
    } catch (e) {
      setState(() => _sendingMessages.removeWhere((m) => m.id == tempId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send message'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Extract mentioned user IDs from text
  List<String> _extractMentionedUserIds(
      String text, List<MentionableUser> users) {
    final mentionedIds = <String>[];
    final mentionPattern = RegExp(r'@(\w+)');

    for (final match in mentionPattern.allMatches(text)) {
      final name = match.group(1)?.toLowerCase();
      if (name != null) {
        for (final user in users) {
          if (user.name.toLowerCase() == name &&
              !mentionedIds.contains(user.userId)) {
            mentionedIds.add(user.userId);
            break;
          }
        }
      }
    }

    return mentionedIds;
  }

  /// Add optimistic voice message to the list immediately
  void _addOptimisticVoiceMessage(ChatMessage message) {
    setState(() {
      _sendingMessages.add(message);
    });

    // Scroll to bottom to show new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAtBottom) _scrollToBottomInstant();
    });
  }

  /// Update status of a voice message (e.g., on failure)
  void _updateVoiceMessageStatus(String messageId, MessageStatus status) {
    setState(() {
      final index = _sendingMessages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        // For now, just keep the message in sending state
        // In the future, could show retry button
      }
    });
  }

  Future<void> _sendNamaste() async {
    if (!_isDMConversation || widget.otherUserId == null) return;

    final result = await NamasteService()
        .sendNamaste(widget.otherUserId!, dmId: widget.spaceId);

    if (!mounted) return;

    if (result.success) {
      setState(() => _namasteSentThisSession = true);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAtBottom) _scrollToBottomInstant();
      });
    } else {
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
  }

  void _navigateToHeader() {
    if (_isDMConversation && widget.otherUserId != null) {
      Navigator.of(context).push(
        CupertinoPageRoute(
            builder: (context) => UserProfilePage(uid: widget.otherUserId)),
      );
    } else if (!_isDMConversation) {
      Navigator.of(context).push(
        CupertinoPageRoute(
            builder: (context) => SpaceScreen(rid: widget.spaceId)),
      );
    }
  }

  void _openMediaGallery() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => MediaGalleryPage(
          spaceId: widget.spaceId,
          title: _displayName ?? 'Media',
        ),
      ),
    );
  }

  void _openMessageSearch() {
    MessageSearchSheet.show(
      context,
      spaceId: widget.spaceId,
      onMessageSelected: (message) {
        // Scroll to the selected message
        _scrollToMessage(message.id);
      },
    );
  }

  void _openConversationOptions() {
    ConversationOptionsSheet.show(
      context,
      conversationId: widget.spaceId,
      conversationName: _displayName ?? 'Chat',
      onSettingsChanged: () {
        // Refresh can be triggered here if needed
      },
    );
  }

  void _startReply(ChatMessage message) {
    if (!kIsWeb) HapticFeedback.lightImpact();
    setState(() => _replyingTo = message);
    _textFieldFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _quickReact(ChatMessage message) {
    if (!kIsWeb) HapticFeedback.mediumImpact();
    _chatService.addReaction(message.id, '❤️');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('❤️', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text('Reacted'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 80, right: 80),
      ),
    );
  }

  void _showExactTime(ChatMessage message) {
    final exactTime =
        DateFormat('EEEE, MMM d, yyyy • h:mm a').format(message.timestamp);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(exactTime,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        backgroundColor:
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final index = _allMessages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    if (!kIsWeb) HapticFeedback.lightImpact();
    final reversedIndex = _allMessages.length - 1 - index;
    final estimatedPosition = reversedIndex * 85.0;

    _scrollController.animateTo(
      estimatedPosition.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<String> _getUserName(String userId) async {
    if (_senderNameCache.containsKey(userId)) {
      final cachedName = _senderNameCache[userId]!;
      // Quick validation: if cached name is not "Deleted User", validate user still exists
      if (cachedName != 'Deleted User') {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            return cachedName; // User still exists, cached name is valid
          }
        } catch (_) {
          // Error checking, fall through to full check
        }
      } else {
        return cachedName; // Already marked as deleted
      }
    }

    try {
      final userService = locator<UserService>();
      // Use cached name from message if available for optimization
      final name = await userService.getUserDisplayName(userId);
      _senderNameCache[userId] = name;
      return name;
    } catch (e) {
      AppLogger.e('Error fetching user name',
          category: LogCategory.ui,
          data: {'userId': userId, 'error': e.toString()});
      // Don't assume deleted on error - return a generic fallback
      // getUserDisplayName already handles deleted users correctly
      return 'Unknown User';
    }
  }

  void _callBack(bool isVideo) {
    if (widget.otherUserId == null) return;
    final callService = GetIt.I<CallService>();
    callService.startCall(
      calleeId: widget.otherUserId!,
      calleeName: _displayName ?? 'User',
      type: isVideo ? CallType.video : CallType.voice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldColor =
        isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;
    final Color headerBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 700 : double.infinity,
            ),
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          headerBase.withValues(alpha: isDark ? 0.85 : 0.90),
                          headerBase.withValues(alpha: isDark ? 0.80 : 0.85),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : headerBase.withValues(alpha: 0.32),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(height: 54, child: _buildHeader()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: scaffoldColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        // Full-width stack so scrollbar appears at viewport edge
        // Use LayoutBuilder to get actual available width
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding =
                Responsive.horizontalPaddingFor(constraints.maxWidth, 700);
            return Stack(
              children: [
                // Messages list fills full width for scrollbar at edge
                Positioned.fill(child: _buildMessagesList(contentPadding)),
                // Accept/Decline banner for pending requests (Instagram-style)
                if (_isPendingRequest)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 54,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 700 : double.infinity,
                        ),
                        child: _buildRequestBanner(isDark),
                      ),
                    ),
                  ),
                // Overlays centered on desktop
                if (!_isDMConversation)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 54,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 700 : double.infinity,
                        ),
                        child: ActiveCallBanner(
                          spaceId: widget.spaceId,
                          spaceName: widget.space?.name ?? 'Group Call',
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 700 : double.infinity,
                      ),
                      child: SpaceChatInputArea(
                        key: ValueKey('chat_input_${widget.spaceId}'),
                        messageController: _messageController,
                        textFieldFocusNode: _textFieldFocusNode,
                        replyingTo: _replyingTo,
                        isDMConversation: _isDMConversation,
                        namasteSentThisSession: _namasteSentThisSession,
                        spaceId: widget.spaceId,
                        onSendMessage: _sendMessage,
                        onSendNamaste: _sendNamaste,
                        onCancelReply: _cancelReply,
                        onTextChanged: _onTextChanged,
                        onOptimisticVoiceMessage: _addOptimisticVoiceMessage,
                        onVoiceMessageStatusUpdate: _updateVoiceMessageStatus,
                        isPendingRequest: _isPendingRequest,
                      ),
                    ),
                  ),
                ),
                if (!_isAtBottom)
                  Positioned(
                    bottom: 140,
                    right: 16 + contentPadding,
                    child: _buildScrollToBottomFAB(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back button with reduced padding
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(Icons.arrow_back_ios,
                  color: AppTheme.primaryColor, size: 22),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _navigateToHeader,
              onLongPress: _openConversationOptions,
              behavior: HitTestBehavior.opaque,
              child: SpaceChatHeaderContent(
                key: ValueKey('header_${widget.otherUserId ?? widget.spaceId}'),
                displayName: _displayName,
                otherUserId: widget.otherUserId,
                isDMConversation: _isDMConversation,
                isLoadingName: _isLoadingName,
                isOtherUserOnline: _isOtherUserOnline,
                otherUserLastSeen: _otherUserLastSeen,
                space: widget.space,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SpaceChatHeaderActions(
            spaceId: widget.spaceId,
            displayName: _displayName,
            otherUserId: widget.otherUserId,
            isDMConversation: _isDMConversation,
            onInfoTap: _navigateToHeader,
            onGalleryTap: _openMediaGallery,
            onSearchTap: _openMessageSearch,
          ),
        ),
      ],
    );
  }

  Widget _buildScrollToBottomFAB() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!kIsWeb) HapticFeedback.lightImpact();
              _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut);
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          barBase.withValues(alpha: 0.75),
                          barBase.withValues(alpha: 0.70),
                        ]
                      : [
                          barBase.withValues(alpha: 0.90),
                          barBase.withValues(alpha: 0.85),
                        ],
                ),
                border: isDark
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      )
                    : null,
              ),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.primary, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestBanner(bool isDark) {
    // Instagram-style: Clean banner with message text and buttons
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkColor : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message text (Instagram-style: simple, centered)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Center(
              child: Text(
                '${_displayName ?? "This person"} wants to send you a message',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Buttons row (Instagram-style: full-width, minimal spacing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _declineRequest,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.errorColor,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _acceptRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Accept',
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

  Future<void> _acceptRequest() async {
    final success = await _chatService.acceptMessageRequest(widget.spaceId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message request accepted'),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to accept request'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _declineRequest() async {
    final success = await _chatService.declineMessageRequest(widget.spaceId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message request deleted'),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
      // Navigate back after declining
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to decline request'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildChatSkeleton() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonChatMessage(isUser: true, lineCount: 1),
        SkeletonChatMessage(lineCount: 3),
        SkeletonChatMessage(isUser: true, lineCount: 2),
        SkeletonChatMessage(lineCount: 2),
        SkeletonChatMessage(lineCount: 1),
        SkeletonChatMessage(isUser: true, lineCount: 3),
        SkeletonChatMessage(lineCount: 2),
        SkeletonChatMessage(isUser: true, lineCount: 1),
      ],
    );
  }

  Widget _buildMessagesList(double horizontalPadding) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.getMessages(widget.spaceId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle,
                    size: 48, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                Text('Error loading messages',
                    style: TextStyle(color: AppTheme.textLightColor)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) return _buildChatSkeleton();

        final messages = snapshot.data!;
        final allMessages = _deduplicateMessages(messages);
        _allMessages = allMessages;
        for (final msg in allMessages) {
          _repliedMessagesCache[msg.id] = msg;
        }

        if (allMessages.isEmpty) return _buildEmptyState();

        return Column(
          children: [
            if (!_isConnected) _buildConnectionBanner(),
            Expanded(
              child: Listener(
                onPointerDown: (_) {
                  setState(() {
                    _totalDragDx = 0;
                    _totalDragDy = 0;
                  });
                },
                onPointerMove: (e) {
                  _totalDragDx += e.delta.dx;
                  _totalDragDy += e.delta.dy;
                  final absDx = _totalDragDx.abs();
                  final absDy = _totalDragDy.abs();
                  if (!_isDraggingReveal &&
                      (absDx > 8 || absDy > 8) &&
                      absDx > absDy) {
                    setState(() => _isDraggingReveal = true);
                  }
                  if (_isDraggingReveal) {
                    setState(() {
                      _timestampRevealOffset =
                          (_timestampRevealOffset - e.delta.dx)
                              .clamp(0.0, _kTimestampRevealStripWidth);
                    });
                  }
                },
                onPointerUp: (_) {
                  setState(() {
                    _isDraggingReveal = false;
                    _timestampRevealOffset = 0.0;
                  });
                },
                onPointerCancel: (_) {
                  setState(() {
                    _isDraggingReveal = false;
                    _timestampRevealOffset = 0.0;
                  });
                },
                child: IgnorePointer(
                  ignoring: _isDraggingReveal,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final contentWidth = w + _kTimestampRevealStripWidth;
                      return Container(
                        width: w,
                        decoration: const BoxDecoration(),
                        clipBehavior: Clip.hardEdge,
                        child: OverflowBox(
                          maxWidth: contentWidth,
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(-_timestampRevealOffset, 0),
                            child: SizedBox(
                              width: contentWidth,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.only(top: 170, bottom: 170),
                                itemCount: allMessages.length +
                                    (_typingUsers.isNotEmpty ? 1 : 0),
                                physics: const ClampingScrollPhysics(),
                                cacheExtent: 2000,
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: false,
                                shrinkWrap: false,
                                reverse: true,
                                itemBuilder: (context, index) {
                                  if (_typingUsers.isNotEmpty && index == 0) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                            width: w,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                  left: 12 + horizontalPadding,
                                                  right:
                                                      12 + horizontalPadding),
                                              child: _buildTypingIndicator(),
                                            )),
                                        const SizedBox(
                                            width: _kTimestampRevealStripWidth),
                                      ],
                                    );
                                  }

                                  final messageIndex = _typingUsers.isNotEmpty
                                      ? index - 1
                                      : index;
                                  final actualIndex =
                                      allMessages.length - 1 - messageIndex;

                                  if (actualIndex < 0 ||
                                      actualIndex >= allMessages.length) {
                                    return const SizedBox.shrink();
                                  }

                                  final message = allMessages[actualIndex];
                                  final isOwnMessage =
                                      message.senderId == _currentUser?.uid;
                                  final isPending = _sendingMessages
                                      .any((m) => m.id == message.id);

                                  bool showDateSeparator = actualIndex == 0 ||
                                      !_isSameDay(
                                          message.timestamp,
                                          allMessages[actualIndex - 1]
                                              .timestamp);

                                  bool isFirstInGroup = true;
                                  bool isLastInGroup = true;

                                  if (actualIndex > 0) {
                                    final prev = allMessages[actualIndex - 1];
                                    final timeDiff = message.timestamp
                                        .difference(prev.timestamp)
                                        .inMinutes;
                                    if (prev.senderId == message.senderId &&
                                        timeDiff < 5 &&
                                        _isSameDay(message.timestamp,
                                            prev.timestamp)) {
                                      isFirstInGroup = false;
                                    }
                                  }

                                  if (actualIndex < allMessages.length - 1) {
                                    final next = allMessages[actualIndex + 1];
                                    final timeDiff = next.timestamp
                                        .difference(message.timestamp)
                                        .inMinutes;
                                    if (next.senderId == message.senderId &&
                                        timeDiff < 5 &&
                                        _isSameDay(message.timestamp,
                                            next.timestamp)) {
                                      isLastInGroup = false;
                                    }
                                  }

                                  final timestampStrip = TimestampRevealStrip(
                                    message: message,
                                    isOwnMessage: isOwnMessage,
                                    isLastInGroup: isLastInGroup,
                                  );

                                  final content = Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (showDateSeparator)
                                        ChatDateSeparator(
                                            date: message.timestamp),
                                      _buildMessageTile(
                                          message,
                                          isOwnMessage,
                                          isPending,
                                          isFirstInGroup,
                                          isLastInGroup),
                                    ],
                                  );

                                  return RepaintBoundary(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                            width: w,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                  left: 12 + horizontalPadding,
                                                  right:
                                                      12 + horizontalPadding),
                                              child: content,
                                            )),
                                        SizedBox(
                                          width: _kTimestampRevealStripWidth,
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                                bottom: isLastInGroup ? 16 : 2),
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: timestampStrip,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<ChatMessage> _deduplicateMessages(List<ChatMessage> messages) {
    final Map<String, ChatMessage> messageMap = {};
    final Set<String> usedRealMessageIds = {};

    for (final sending in _sendingMessages) {
      final realMessage = messages.firstWhere(
        (real) => _isMatchingMessage(real, sending),
        orElse: () => ChatMessage(
          id: '',
          spaceId: '',
          senderId: '',
          senderName: '',
          content: '',
          messageType: '',
          reactions: {},
          readBy: [],
          timestamp: DateTime.now(),
        ),
      );

      if (realMessage.id.isNotEmpty) {
        messageMap[sending.id] = realMessage;
        usedRealMessageIds.add(realMessage.id);
      } else {
        messageMap[sending.id] = sending;
      }
    }

    for (final message in messages) {
      if (!usedRealMessageIds.contains(message.id)) {
        messageMap[message.id] = message;
      }
    }

    _sendingMessages.removeWhere(
        (sending) => messages.any((real) => _isMatchingMessage(real, sending)));

    final allMessages = messageMap.values.toList();
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allMessages;
  }

  /// Check if a real message matches a sending (optimistic) message
  bool _isMatchingMessage(ChatMessage real, ChatMessage sending) {
    // Must be same sender and message type
    if (real.senderId != sending.senderId) return false;
    if (real.messageType != sending.messageType) return false;

    // Timestamp must be within 30 seconds (allow more time for voice uploads)
    final timeDiff =
        real.timestamp.difference(sending.timestamp).inSeconds.abs();
    if (timeDiff > 30) return false;

    // For voice messages, match by duration (fileSize)
    if (sending.messageType == 'audio') {
      return real.fileSize == sending.fileSize;
    }

    // For text and other messages, match by content
    return real.content == sending.content;
  }

  Widget _buildMessageTile(ChatMessage message, bool isOwnMessage,
      bool isPending, bool isFirstInGroup, bool isLastInGroup) {
    if (message.messageType == 'namaste') {
      return NamasteMessageTile(
        message: message,
        isOwnMessage: isOwnMessage,
        isLastInGroup: isLastInGroup,
        onShowTime: () => _showExactTime(message),
      );
    }

    if (message.messageType == 'call') {
      return CallMessageTile(
        message: message,
        isLastInGroup: isLastInGroup,
        currentUserId: _currentUser?.uid,
        onShowTime: () => _showExactTime(message),
        onCallback: widget.otherUserId != null
            ? () => _callBack(message.callType == 'video')
            : null,
      );
    }

    if (message.messageType == 'group_call') {
      return GroupCallMessageTile(
        message: message,
        isLastInGroup: isLastInGroup,
        onShowTime: () => _showExactTime(message),
      );
    }

    return ChatMessageTile(
      message: message,
      isOwnMessage: isOwnMessage,
      isPending: isPending,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      currentUserId: _currentUser?.uid,
      onReply: () => _startReply(message),
      onQuickReact: () => _quickReact(message),
      onShowTime: () => _showExactTime(message),
      onLongPress: () => _showMessageOptions(message, isOwnMessage),
      onShowReactions: message.reactions.isNotEmpty
          ? () => _showReactionsSheet(message)
          : null,
      onForward: () => _forwardMessage(message),
      onEdit: _chatService.canEditMessage(message)
          ? () => _showEditMessageDialog(message)
          : null,
      repliedMessagesCache: _repliedMessagesCache,
      onScrollToMessage: _scrollToMessage,
      isDMConversation: _isDMConversation,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100),
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
              child: Icon(CupertinoIcons.chat_bubble_2,
                  size: 36,
                  color: AppTheme.primaryColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text('No messages yet',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Start the conversation!',
                style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.orange[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Text('No internet connection',
              style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDots(),
                const SizedBox(width: 8),
                Text(
                  _typingUsers.length == 1
                      ? '${_typingUsers.first.userName.trim().isEmpty ? 'Someone' : _typingUsers.first.userName} is typing'
                      : '${_typingUsers.length} people are typing',
                  style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          3,
          (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.only(right: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              )),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showMessageOptions(ChatMessage message, bool isOwnMessage) {
    if (!kIsWeb) HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.surfaceDarkColor
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reactions at the top with transparent background
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children:
                              ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _chatService.addReaction(message.id, emoji);
                                if (!kIsWeb) HapticFeedback.lightImpact();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 24)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.reply_rounded,
                            color: AppTheme.primaryColor),
                        title: Text('Reply',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500)),
                        onTap: () {
                          Navigator.pop(context);
                          _startReply(message);
                        },
                      ),
                      if (message.messageType == 'text')
                        ListTile(
                          leading: Icon(Icons.copy_rounded,
                              color: AppTheme.primaryColor),
                          title: Text('Copy message',
                              style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500)),
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: message.content));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Message copied'),
                                backgroundColor: AppTheme.primaryColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      if (_chatService.canEditMessage(message))
                        ListTile(
                          leading: Icon(Icons.edit_rounded,
                              color: AppTheme.primaryColor),
                          title: Text('Edit message',
                              style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500)),
                          onTap: () {
                            Navigator.pop(context);
                            _showEditMessageDialog(message);
                          },
                        ),
                      ListTile(
                        leading: Icon(Icons.shortcut_rounded,
                            color: AppTheme.primaryColor),
                        title: Text('Forward',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500)),
                        onTap: () {
                          Navigator.pop(context);
                          _forwardMessage(message);
                        },
                      ),
                      if (!isOwnMessage) ...[
                        // Report option for messages from other users
                        ListTile(
                          leading: Icon(Icons.flag_outlined,
                              color: AppTheme.errorColor),
                          title: Text('Report message',
                              style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.w500)),
                          onTap: () {
                            Navigator.pop(context);
                            _showReportMessageDialog(message);
                          },
                        ),
                        // Block user option for DM conversations
                        if (_isDMConversation && widget.otherUserId != null)
                          ListTile(
                            leading: Icon(Icons.block,
                                color: AppTheme.errorColor),
                            title: Text('Block user',
                                style: TextStyle(
                                    color: AppTheme.errorColor,
                                    fontWeight: FontWeight.w500)),
                            onTap: () {
                              Navigator.pop(context);
                              _showBlockUserDialog();
                            },
                          ),
                      ],
                      if (isOwnMessage)
                        ListTile(
                          leading: Icon(Icons.delete_outline_rounded,
                              color: AppTheme.errorColor),
                          title: Text('Delete message',
                              style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.w500)),
                          onTap: () {
                            Navigator.pop(context);
                            _confirmDeleteMessage(message);
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReactionsSheet(ChatMessage message) {
    final currentUserId = _currentUser?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.cardDarkColor
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Reactions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  _chatService.removeReaction(message.id);
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
                                    borderRadius: BorderRadius.circular(16),
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
                                _chatService.removeReaction(message.id);
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
      ),
    );
  }

  void _confirmDeleteMessage(ChatMessage message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
            'Are you sure you want to delete this message? This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              _chatService.deleteMessage(message.id);
            },
          ),
        ],
      ),
    );
  }

  void _showEditMessageDialog(ChatMessage message) {
    final textController = TextEditingController(text: message.content);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Message'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: textController,
            placeholder: 'Enter new message',
            maxLines: 5,
            minLines: 1,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final newContent = textController.text.trim();
              if (newContent.isEmpty) {
                return;
              }
              if (newContent == message.content) {
                Navigator.pop(context);
                return;
              }

              Navigator.pop(context);

              try {
                await _chatService.editMessage(message.id, newContent);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Message edited'),
                      backgroundColor: AppTheme.primaryColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to edit message: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    // Create shareable content from the message
    final content = ShareableContent(
      type: 'message',
      id: message.id,
      title: message.messageType == 'text'
          ? (message.content.length > 50
              ? '${message.content.substring(0, 50)}...'
              : message.content)
          : _getMessageTypeLabel(message.messageType),
      subtitle: message.senderName,
      imageUrl: message.thumbnailUrl ??
          (message.messageType == 'image' ? message.mediaUrl : null),
    );

    final result = await ChatPickerBottomSheet.show(
      context,
      content: content,
      allowMultiSelect: true,
    );

    if (result != null && result.selectedConversations.isNotEmpty) {
      // Forward to all selected conversations
      int successCount = 0;
      for (final conversation in result.selectedConversations) {
        try {
          await _chatService.forwardMessage(
            targetSpaceId: conversation.id,
            originalMessage: message,
            additionalMessage: result.message,
          );
          successCount++;
        } catch (e) {
          AppLogger.e('Failed to forward to ${conversation.id}',
              category: LogCategory.general, error: e);
        }
      }

      if (mounted && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successCount == 1
                ? 'Message forwarded'
                : 'Message forwarded to $successCount chats'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getMessageTypeLabel(String messageType) {
    switch (messageType) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Voice message';
      case 'file':
        return 'File';
      case 'shared_content':
        return 'Shared content';
      default:
        return 'Message';
    }
  }

  void _showReportMessageDialog(ChatMessage message) {
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Report Message'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Why are you reporting this message?',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: textController,
                placeholder: 'Enter reason',
                maxLines: 4,
                minLines: 2,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            isDefaultAction: true,
            child: const Text('Report'),
            onPressed: () async {
              final reason = textController.text.trim();
              if (reason.isEmpty) {
                return;
              }

              Navigator.pop(context);

              await _chatService.reportChatMessage(message.id, reason);

              if (mounted) {
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const Text('Reported'),
                    content: const Text(
                        'Thank you for reporting this message. It will be reviewed by our team within 24 hours.\n\nIt is our priority to keep Aurogram free of objectionable content and your support for the same is appreciated.'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog() {
    if (widget.otherUserId == null) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Block User'),
        content: Text(
            'Are you sure you want to block ${_displayName ?? 'this user'}? You will no longer receive messages from them.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Block'),
            onPressed: () async {
              Navigator.pop(context);

              try {
                final userService = UserService();
                await userService.blockUser(widget.otherUserId!);

                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('User Blocked'),
                      content: const Text(
                          'This user has been blocked. You will no longer receive messages from them.'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('OK'),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context); // Also pop chat screen
                          },
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                AppLogger.e('Error blocking user',
                    category: LogCategory.general, error: e);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Failed to block user'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
