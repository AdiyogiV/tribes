import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/services/chat/chat_notification_service.dart';
import 'package:aurogram/services/namaste_service.dart';
import 'package:aurogram/widgets/call/active_call_banner.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/user_service.dart';

// Reuse existing widgets from spaceChatScreen
import 'package:aurogram/pages/spaces/widgets/space_chat_header.dart';
import 'package:aurogram/pages/spaces/widgets/space_chat_input.dart';
import 'package:aurogram/pages/spaces/widgets/chat_message_tiles.dart';
import 'package:aurogram/pages/spaces/widgets/media_gallery_page.dart';
import 'package:aurogram/widgets/chat/message_search_sheet.dart';

/// An embeddable chat view that can be used inside a master-detail layout.
/// Unlike SpaceChatScreen, this doesn't use its own Scaffold and is designed
/// to be embedded within another widget tree.
class EmbeddedChatView extends StatefulWidget {
  final String spaceId;
  final Space? space;
  final String? otherUserId;

  /// Optional callback when back is pressed (for desktop, may want to deselect)
  final VoidCallback? onBack;

  /// Whether to show the header (can hide if parent provides header)
  final bool showHeader;

  const EmbeddedChatView({
    super.key,
    required this.spaceId,
    this.space,
    this.otherUserId,
    this.onBack,
    this.showHeader = true,
  });

  @override
  EmbeddedChatViewState createState() => EmbeddedChatViewState();
}

class EmbeddedChatViewState extends State<EmbeddedChatView> {
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

  bool get _isDMConversation => widget.spaceId.startsWith('dm_');

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

    _listenToTypingUsers();
  }

  void _listenToTypingUsers() {
    _typingSubscription = _chatService.getTypingUsers(widget.spaceId).listen(
      (users) {
        if (mounted) {
          setState(() => _typingUsers = users);
        }
      },
      onError: (e) {
        AppLogger.w('Error listening to typing users',
            category: LogCategory.ui, data: {'error': e.toString()});
      },
    );
  }

  @override
  void didUpdateWidget(EmbeddedChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the spaceId changes, reload everything
    if (oldWidget.spaceId != widget.spaceId) {
      ChatNotificationService.setActiveChat(widget.spaceId);
      _typingSubscription?.cancel();
      _onlineStatusSubscription?.cancel();
      _sendingMessages.clear();
      _allMessages.clear();
      _repliedMessagesCache.clear();
      _replyingTo = null;
      _namasteSentThisSession = false;

      if (_isDMConversation && widget.otherUserId != null) {
        _loadDisplayName();
        _listenToOnlineStatus();
      } else {
        _displayName = widget.space?.name ?? 'Chat';
      }

      _listenToTypingUsers();
    }
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
      // Reverse list: bottom = offset 0 (newest messages)
      _isAtBottom = _scrollController.offset <= 80;
      if (wasAtBottom != _isAtBottom) setState(() {});
    }
  }

  void _onTextChanged(String text) {
    if (text.trim().isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
      _chatService.setTyping(widget.spaceId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isTyping) {
        setState(() => _isTyping = false);
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
    _typingSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _typingTimer?.cancel();
    _chatService.setTyping(widget.spaceId, false);
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  double get _bottomScrollOffset => 0;

  void _scrollToBottomInstant() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_bottomScrollOffset);
    }
  }

  void _forceScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(_bottomScrollOffset,
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
      await _chatService.sendTextMessage(widget.spaceId, message,
          replyTo: replyToId);
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

  void _startReply(ChatMessage message) {
    HapticFeedback.lightImpact();
    setState(() => _replyingTo = message);
    _textFieldFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _quickReact(ChatMessage message) {
    HapticFeedback.mediumImpact();
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final index = _allMessages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    HapticFeedback.lightImpact();
    final reversedIndex = _allMessages.length - 1 - index;
    final estimatedPosition = reversedIndex * 85.0;

    _scrollController.animateTo(
      estimatedPosition.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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

  static const double _chatHeaderRowHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldColor =
        isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;

    return Container(
      color: scaffoldColor,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            if (widget.showHeader) _buildHeaderContent(isDark),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildMessagesList()),
                  if (!_isDMConversation)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ActiveCallBanner(
                        spaceId: widget.spaceId,
                        spaceName: widget.space?.name ?? 'Group Call',
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SpaceChatInputArea(
                      key: ValueKey('chat_input_${widget.spaceId}'),
                      spaceId: widget.spaceId,
                      messageController: _messageController,
                      textFieldFocusNode: _textFieldFocusNode,
                      replyingTo: _replyingTo,
                      isDMConversation: _isDMConversation,
                      namasteSentThisSession: _namasteSentThisSession,
                      onSendMessage: _sendMessage,
                      onSendNamaste: _sendNamaste,
                      onCancelReply: _cancelReply,
                      onTextChanged: _onTextChanged,
                      onOptimisticVoiceMessage: _addOptimisticVoiceMessage,
                      onVoiceMessageStatusUpdate: _updateVoiceMessageStatus,
                    ),
                  ),
                  if (!_isAtBottom)
                    Positioned(
                      bottom: 140,
                      right: 16,
                      child: _buildScrollToBottomFAB(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header height for overlay and top padding. Matches wide layout.
  double get _headerHeight {
    final topInset = MediaQuery.of(context).padding.top;
    return topInset +
        AppHeaderStyle.wideLayoutHeaderTitleTopPadding +
        _chatHeaderRowHeight +
        10;
  }

  /// Header at top. Same look as wide layout (top padding + row).
  Widget _buildHeaderContent(bool isDark) {
    final topInset = MediaQuery.of(context).padding.top;
    final headerBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: headerBase.withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: topInset + AppHeaderStyle.wideLayoutHeaderTitleTopPadding,
            left: 0,
            right: 0,
            height: _chatHeaderRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: Icon(Icons.arrow_back_ios,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    onTap: _navigateToHeader,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding:
                          EdgeInsets.only(left: widget.onBack != null ? 0 : 16),
                      child: SpaceChatHeaderContent(
                        key: ValueKey(
                            'header_${widget.otherUserId ?? widget.spaceId}'),
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
                  padding: const EdgeInsets.only(right: 8),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomFAB() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color barBase =
        isDark ? AppTheme.cardDarkColor : Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _scrollController.animateTo(_bottomScrollOffset,
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

  Widget _buildMessagesList() {
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
                      final contentWidth =
                          w + _kTimestampRevealStripWidth;
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
                            padding: const EdgeInsets.only(
                                top: 70,
                                bottom: 170),
                            itemCount: allMessages.length +
                                (_typingUsers.isNotEmpty ? 1 : 0),
                            physics:
                                const ClampingScrollPhysics(),
                            cacheExtent: 2000,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: false,
                            shrinkWrap: false,
                            reverse: true,
                            itemBuilder: (context, index) {
                              if (_typingUsers.isNotEmpty &&
                                  index == 0) {
                                return Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                        width: w,
                                        child: Padding(
                                          padding: const EdgeInsets
                                              .only(
                                                  left: 12,
                                                  right: 12),
                                          child:
                                              _buildTypingIndicator(),
                                        )),
                                    const SizedBox(
                                        width:
                                            _kTimestampRevealStripWidth),
                                  ],
                                );
                              }

                              final messageIndex =
                                  _typingUsers.isNotEmpty
                                      ? index - 1
                                      : index;
                              final actualIndex = allMessages
                                      .length -
                                  1 -
                                  messageIndex;

                              if (actualIndex < 0 ||
                                  actualIndex >=
                                      allMessages.length) {
                                return const SizedBox.shrink();
                              }

                              final message =
                                  allMessages[actualIndex];
                              final isOwnMessage = message
                                      .senderId ==
                                  _currentUser?.uid;
                              final isPending =
                                  _sendingMessages
                                      .any((m) =>
                                          m.id == message.id);

                              bool showDateSeparator =
                                  actualIndex == 0 ||
                                      !_isSameDay(
                                          message.timestamp,
                                          allMessages[
                                                  actualIndex -
                                                      1]
                                              .timestamp);

                              bool isFirstInGroup = true;
                              bool isLastInGroup = true;

                              if (actualIndex > 0) {
                                final prev = allMessages[
                                    actualIndex - 1];
                                final timeDiff = message
                                    .timestamp
                                    .difference(
                                        prev.timestamp)
                                    .inMinutes;
                                if (prev.senderId ==
                                        message.senderId &&
                                    timeDiff < 5 &&
                                    _isSameDay(message
                                        .timestamp, prev
                                        .timestamp)) {
                                  isFirstInGroup = false;
                                }
                              }

                              if (actualIndex <
                                  allMessages.length - 1) {
                                final next = allMessages[
                                    actualIndex + 1];
                                final timeDiff = next
                                    .timestamp
                                    .difference(message
                                        .timestamp)
                                    .inMinutes;
                                if (next.senderId ==
                                        message.senderId &&
                                    timeDiff < 5 &&
                                    _isSameDay(message
                                        .timestamp, next
                                        .timestamp)) {
                                  isLastInGroup = false;
                                }
                              }

                              final timestampStrip =
                                  TimestampRevealStrip(
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
                                          padding: const EdgeInsets
                                              .only(
                                                  left: 12,
                                                  right: 12),
                                          child: content,
                                        )),
                                    SizedBox(
                                        width:
                                            _kTimestampRevealStripWidth,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                              bottom: isLastInGroup
                                                  ? 16
                                                  : 2),
                                          child: Align(
                                            alignment: Alignment
                                                .centerRight,
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
        orElse: () => sending,
      );

      if (realMessage != sending) {
        usedRealMessageIds.add(realMessage.id);
        messageMap[realMessage.id] = realMessage;
      } else {
        messageMap[sending.id] = sending;
      }
    }

    for (final message in messages) {
      if (!usedRealMessageIds.contains(message.id) &&
          !message.id.startsWith('sending_')) {
        messageMap[message.id] = message;
      }
    }

    // Remove matched sending messages
    _sendingMessages.removeWhere(
        (sending) => messages.any((real) => _isMatchingMessage(real, sending)));

    final result = messageMap.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.orange.withValues(alpha: 0.9),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Connecting...',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
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

  Widget _buildMessageTile(
    ChatMessage message,
    bool isOwnMessage,
    bool isPending,
    bool isFirstInGroup,
    bool isLastInGroup,
  ) {
    // Handle namaste messages
    if (message.messageType == 'namaste') {
      return NamasteMessageTile(
        message: message,
        isOwnMessage: isOwnMessage,
        isLastInGroup: isLastInGroup,
        onShowTime: () => _showExactTime(message),
      );
    }

    // Handle call messages
    if (message.messageType == 'call') {
      return CallMessageTile(
        message: message,
        isLastInGroup: isLastInGroup,
        currentUserId: _currentUser?.uid,
        onShowTime: () => _showExactTime(message),
        onCallback: null, // Callbacks not supported in embedded view
      );
    }

    // Handle group call messages
    if (message.messageType == 'group_call') {
      return GroupCallMessageTile(
        message: message,
        isLastInGroup: isLastInGroup,
        onShowTime: () => _showExactTime(message),
      );
    }

    // Default: text, image, etc.
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
      onLongPress: () => _showExactTime(message),
      repliedMessagesCache: _repliedMessagesCache,
      onScrollToMessage: _scrollToMessage,
      isDMConversation: _isDMConversation,
    );
  }
}
