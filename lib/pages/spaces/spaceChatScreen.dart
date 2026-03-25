import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/pages/tabs/userProfile.dart';
import 'package:aurogram/pages/spaces/spaceScreen.dart';
import 'package:aurogram/services/chat/chat_notification_service.dart';
import 'package:aurogram/services/namaste_service.dart';

class SpaceChatScreen extends StatefulWidget {
  final String spaceId;
  final Space? space; // Nullable for DM conversations opened via notification
  final String? otherUserId; // For DM conversations - the other user's ID

  const SpaceChatScreen({
    Key? key,
    required this.spaceId,
    this.space,
    this.otherUserId,
  }) : super(key: key);

  @override
  SpaceChatScreenState createState() => SpaceChatScreenState();
}

class SpaceChatScreenState extends State<SpaceChatScreen> {
  final SpaceChatService _chatService = SpaceChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Cache for sender names to avoid repeated Firebase calls
  static final Map<String, String> _senderNameCache = {};

  // Cache for chat display name (for DM conversations)
  String? _displayName;
  bool _isLoadingName = false;

  // Pending messages for optimistic UI (sending status only)
  final List<ChatMessage> _sendingMessages = [];

  // Track if we're at the bottom for auto-scroll behavior
  bool _isAtBottom = true;

  // Connection status
  final bool _isConnected = true;

  // Typing indicators
  final Set<String> _typingUsers = {};
  bool _isTyping = false;
  Timer? _typingTimer;

  // Reply state
  ChatMessage? _replyingTo;

  // Cache for replied messages (messageId -> ChatMessage)
  final Map<String, ChatMessage> _repliedMessagesCache = {};

  // Store message list for scroll-to functionality
  List<ChatMessage> _allMessages = [];

  // Online status for DMs
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  StreamSubscription? _onlineStatusSubscription;

  // Track if namaste was sent in this session (to hide namaste button after sending)
  bool _namastesentThisSession = false;

  @override
  void initState() {
    super.initState();
    
    // Track this chat as active to suppress notifications
    ChatNotificationService.setActiveChat(widget.spaceId);
    
    // Add scroll listener for better scroll tracking
    _scrollController.addListener(_onScroll);

    // Add focus listener to rebuild UI when focus changes
    _textFieldFocusNode.addListener(() {
      setState(() {});

      // Auto-scroll to bottom when text field is focused
      if (_textFieldFocusNode.hasFocus) {
        _forceScrollToBottom();

        // Multiple attempts to handle keyboard animation
        for (int delay in [50, 150, 300, 500]) {
          Future.delayed(Duration(milliseconds: delay), () {
            _forceScrollToBottom();
          });
        }
      }
    });

    // Load display name for DM conversations
    if (_isDMConversation && widget.otherUserId != null) {
      _loadDisplayName();
      _listenToOnlineStatus();
    } else {
      _displayName = widget.space?.name ?? 'Chat';
    }
  }

  /// Listen to online status of the other user in DM
  void _listenToOnlineStatus() {
    if (widget.otherUserId == null) return;

    _onlineStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        final isOnline = data?['isOnline'] as bool? ?? false;
        final lastSeen = data?['lastSeen'] as Timestamp?;

        setState(() {
          _isOtherUserOnline = isOnline;
          _otherUserLastSeen = lastSeen?.toDate();
        });
      }
    });
  }

  /// Load the display name for DM conversations
  Future<void> _loadDisplayName() async {
    if (widget.otherUserId == null) {
      _displayName = widget.space?.name ?? 'Chat';
      return;
    }

    setState(() {
      _isLoadingName = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId!)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          final name = userData['name'] as String? ??
              userData['nickname'] as String? ??
              widget.space?.name ?? 'Chat';

          if (mounted) {
            setState(() {
              _displayName = name;
              _isLoadingName = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      AppLogger.w('Error loading display name for chat',
          category: LogCategory.ui, data: {'error': e.toString()});
    }

    // Fallback to space name
    if (mounted) {
      setState(() {
        _displayName = widget.space?.name ?? 'Chat';
        _isLoadingName = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      // With reverse: true, bottom is at offset 0
      // Consider "at bottom" if within 100 pixels of position 0
      final wasAtBottom = _isAtBottom;
      _isAtBottom = _scrollController.offset <= 100;
      
      // Trigger rebuild to show/hide scroll FAB
      if (wasAtBottom != _isAtBottom) {
        setState(() {});
      }
    }
  }

  void _onTextChanged(String text) {
    // Update send button state immediately for smooth UI
    setState(() {});

    // Handle typing indicator
    if (text.trim().isNotEmpty && !_isTyping) {
      setState(() {
        _isTyping = true;
      });
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Clear active chat tracking
    ChatNotificationService.clearActiveChat();
    
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _onlineStatusSubscription?.cancel();
    _typingTimer?.cancel();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottomInstant() {
    if (_scrollController.hasClients) {
      // With reverse: true, bottom is at position 0
      _scrollController.jumpTo(0);
    }
  }

  void _forceScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        // With reverse: true, bottom is at position 0
        _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Capture reply before clearing
    final replyToMessage = _replyingTo;
    final replyToId = replyToMessage?.id;

    // Create sending message for immediate UI feedback
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

    // Clear input AND reply state immediately
    _messageController.clear();
    setState(() {
      _sendingMessages.add(sendingMessage);
      _replyingTo = null;
    });

    // Auto-scroll to show the sending message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAtBottom) {
        _scrollToBottomInstant();
      }
    });

    try {
      // Pass replyTo to the service
      await _chatService.sendTextMessage(widget.spaceId, message, replyTo: replyToId);

      // Auto-scroll to show the confirmed message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAtBottom) {
          _scrollToBottomInstant();
        }
      });
    } catch (e) {
      // Remove sending message and show error
      setState(() {
        _sendingMessages.removeWhere((m) => m.id == tempId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Determine if this is a DM conversation
  bool get _isDMConversation => widget.spaceId.startsWith('dm_');

  /// Send namaste greeting in this chat
  /// Backend handles notification, aura, chat message, and quota
  Future<void> _sendNamaste() async {
    if (!_isDMConversation || widget.otherUserId == null) return;
    
    // Send via backend (handles everything including chat message)
    final result = await NamasteService().sendNamaste(
      widget.otherUserId!, 
      dmId: widget.spaceId,
    );
    
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _namastesentThisSession = true;
      });
      
      // Auto-scroll to show the namaste message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAtBottom) {
          _scrollToBottomInstant();
        }
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

  /// Navigate to user profile (for DMs) or space (for space chats)
  void _navigateToHeader() {
    if (_isDMConversation && widget.otherUserId != null) {
      // Navigate to user profile for DM conversations
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => UserProfilePage(uid: widget.otherUserId),
        ),
      );
    } else if (!_isDMConversation) {
      // Navigate to space for space chats
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => SpaceScreen(rid: widget.spaceId),
        ),
      );
    }
  }

  /// Build aligned chat header matching app's universal header pattern
  /// Uses same layout as AppHeaderStyle.buildUniversalHeaderContent for consistency
  Widget _buildAlignedChatHeader() {
    // Match header structure: sideWidth=86, horizontalPadding=30
    const double sideWidth = 86.0;
    const double horizontalPadding = 30.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Back button area with fixed width
        SizedBox(
          width: sideWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: horizontalPadding),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.arrow_back_ios,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        // Center: Avatar + Name (left-aligned horizontally, centered vertically)
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _navigateToHeader,
              behavior: HitTestBehavior.opaque,
              child: _buildChatHeaderContent(),
            ),
          ),
        ),
        // Right: Action area with same width for symmetry
        SizedBox(
          width: sideWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: horizontalPadding),
              child: GestureDetector(
                onTap: _navigateToHeader,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  _isDMConversation ? Icons.person_outline_rounded : Icons.info_outline_rounded,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build the centered header content with avatar, name, and status
  Widget _buildChatHeaderContent() {
    if (_isLoadingName) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar skeleton
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10),
          // Name skeleton
          Container(
            width: 80,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      );
    }

    final displayName = _displayName ?? widget.space?.name ?? 'Chat';

    // Build status text (online/last seen)
    String? statusText;
    Color statusColor = AppTheme.primaryColor.withValues(alpha: 0.5);
    
    if (_isDMConversation) {
      if (_isOtherUserOnline) {
        statusText = 'Active now';
        statusColor = Color(0xFF4CAF50);
      } else if (_otherUserLastSeen != null) {
        statusText = 'Last seen ${_formatLastSeen(_otherUserLastSeen!)}';
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with online indicator
        Stack(
          children: [
            Material(
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: _isDMConversation && widget.otherUserId != null
                  ? UserAvatar(
                      userId: widget.otherUserId!,
                      size: 34,
                      loadFromFirestore: true,
                      nameInitials: displayName.isNotEmpty 
                          ? displayName.substring(0, 1).toUpperCase() 
                          : 'U',
                      showBorder: false,
                    )
                  : Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.group_rounded,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ),
            ),
            // Online indicator dot
            if (_isDMConversation && _isOtherUserOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: 10),
        // Name and status - centered column
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (statusText != null) ...[
              SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isOtherUserOnline) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4),
                  ],
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldColor = isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;
    final Color headerBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(54),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: headerBase.withValues(alpha: isDark ? 0.85 : 0.88),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 54,
                    child: _buildAlignedChatHeader(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: scaffoldColor,
      body: GestureDetector(
        onTap: () {
          // Hide keyboard when tapping outside text field
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            // Messages list with bottom padding for input
            Positioned.fill(
              child: _buildMessagesList(),
            ),
            // Transparent toolbox input at bottom with reply preview
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null) _buildReplyPreview(),
                  TransparentToolbox.chat(
                    messageController: _messageController,
                    focusNode: _textFieldFocusNode,
                    onSend: _sendMessage,
                    onChanged: _onTextChanged,
                    hintText: _replyingTo != null
                        ? 'Reply to ${_replyingTo!.senderName}...'
                        : 'Type message',
                    canSend: _messageController.text.trim().isNotEmpty,
                    // Namaste button for DM conversations
                    onNamaste: _isDMConversation ? _sendNamaste : null,
                    showNamasteButton: _isDMConversation && !_namastesentThisSession,
                  ),
                ],
              ),
            ),
            // Scroll to bottom FAB
            if (!_isAtBottom)
              Positioned(
                bottom: 100,
                right: 16,
                child: _buildScrollToBottomFAB(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToBottomFAB() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          // With reverse: true, bottom is at position 0
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.primaryColor,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildChatSkeleton() {
    // Instant display chat skeleton with varied line counts for organic look
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
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 48,
                  color: AppTheme.errorColor,
                ),
                SizedBox(height: 16),
                Text(
                  'Error loading messages',
                  style: TextStyle(color: AppTheme.textLightColor),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return _buildChatSkeleton();
        }

        final messages = snapshot.data!;

        // Smart deduplication - prevent both sending and real message from showing
        final Map<String, ChatMessage> messageMap = {};
        final Set<String> usedRealMessageIds = <String>{};

        // First: Process sending messages and match with real ones
        for (final sending in _sendingMessages) {
          final realMessage = messages.firstWhere(
            (real) =>
                real.senderId == sending.senderId &&
                real.content == sending.content &&
                real.messageType == sending.messageType &&
                real.timestamp.difference(sending.timestamp).inSeconds.abs() <
                    10,
            orElse: () => ChatMessage(
                id: '',
                spaceId: '',
                senderId: '',
                senderName: '',
                content: '',
                messageType: '',
                reactions: {},
                readBy: [],
                timestamp: DateTime.now()),
          );

          if (realMessage.id.isNotEmpty) {
            // Found real version - use real data but keep sending position
            messageMap[sending.id] = realMessage;
            usedRealMessageIds
                .add(realMessage.id); // Mark as used to prevent duplicate
          } else {
            // No real version yet - keep sending message
            messageMap[sending.id] = sending;
          }
        }

        // Second: Add real messages that weren't matched (prevent duplicates)
        for (final message in messages) {
          if (!usedRealMessageIds.contains(message.id)) {
            messageMap[message.id] = message;
          }
        }

        // Silent cleanup of matched sending messages
        _sendingMessages.removeWhere((sending) => messages.any((real) =>
            real.senderId == sending.senderId &&
            real.content == sending.content &&
            real.messageType == sending.messageType &&
            real.timestamp.difference(sending.timestamp).inSeconds.abs() < 10));

        final allMessages = messageMap.values.toList();

        // Sort by timestamp to maintain order
        allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Cache all messages for reply lookup and scroll-to
        _allMessages = allMessages;
        for (final msg in allMessages) {
          _repliedMessagesCache[msg.id] = msg;
        }

        if (allMessages.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 100),
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
                      CupertinoIcons.chat_bubble_2,
                      size: 36,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start the conversation!',
                    style: TextStyle(
                      color: AppTheme.primaryColor.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Removed debug logging for better performance
        // With reverse: true, list automatically starts at bottom (position 0)
        // No need for initial scroll handling

        return Column(
          children: [
            // Connection status indicator
            if (!_isConnected)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8),
                color: Colors.orange[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 16, color: Colors.orange[700]),
                    SizedBox(width: 8),
                    Text(
                      'No internet connection',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(left: 12, right: 12, top: 170, bottom: 120),
                itemCount:
                    allMessages.length + (_typingUsers.isNotEmpty ? 1 : 0),
                physics: ClampingScrollPhysics(),
                cacheExtent: 2000, // Aggressive caching for production
                addAutomaticKeepAlives:
                    false, // Don't keep off-screen items alive
                addRepaintBoundaries:
                    false, // Let Flutter decide on repaint boundaries
                shrinkWrap: false, // Better performance
                reverse: true, // Messages stay bottom-aligned when few
                itemBuilder: (context, index) {
                  // With reverse: true, index 0 is the newest message (bottom)
                  // Show typing indicator at index 0 (bottom)
                  if (_typingUsers.isNotEmpty && index == 0) {
                    return _buildTypingIndicator();
                  }
                  
                  // Adjust index for typing indicator
                  final messageIndex = _typingUsers.isNotEmpty ? index - 1 : index;
                  // Convert reversed index to actual message index (newest first in reversed list)
                  final actualIndex = allMessages.length - 1 - messageIndex;
                  
                  if (actualIndex < 0 || actualIndex >= allMessages.length) {
                    return SizedBox.shrink();
                  }
                  
                  final message = allMessages[actualIndex];
                  final isOwnMessage = message.senderId == _currentUser?.uid;
                  final isPending =
                      _sendingMessages.any((m) => m.id == message.id);

                  // Check if we need a date separator (shown above message in visual order)
                  // In reversed list, we check the message BEFORE in the actual order
                  bool showDateSeparator = false;
                  if (actualIndex == 0) {
                    showDateSeparator = true;
                  } else {
                    final previousMessage = allMessages[actualIndex - 1];
                    showDateSeparator = !_isSameDay(message.timestamp, previousMessage.timestamp);
                  }

                  // Check for message grouping
                  bool isFirstInGroup = true;
                  bool isLastInGroup = true;

                  if (actualIndex > 0) {
                    final previousMessage = allMessages[actualIndex - 1];
                    final timeDiff = message.timestamp
                        .difference(previousMessage.timestamp)
                        .inMinutes;
                    final sameDay = _isSameDay(message.timestamp, previousMessage.timestamp);
                    if (previousMessage.senderId == message.senderId &&
                        timeDiff < 5 && sameDay) {
                      isFirstInGroup = false;
                    }
                  }

                  if (actualIndex < allMessages.length - 1) {
                    final nextMessage = allMessages[actualIndex + 1];
                    final timeDiff = nextMessage.timestamp
                        .difference(message.timestamp)
                        .inMinutes;
                    final sameDay = _isSameDay(message.timestamp, nextMessage.timestamp);
                    if (nextMessage.senderId == message.senderId &&
                        timeDiff < 5 && sameDay) {
                      isLastInGroup = false;
                    }
                  }

                  return RepaintBoundary(
                    child: Column(
                      children: [
                        if (showDateSeparator)
                          _buildDateSeparator(message.timestamp),
                        _buildMessageTile(
                          message,
                          isOwnMessage,
                          isPending: isPending,
                          isFirstInGroup: isFirstInGroup,
                          isLastInGroup: isLastInGroup,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageTile(
    ChatMessage message,
    bool isOwnMessage, {
    bool isPending = false,
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
  }) {
    // Special rendering for namaste messages - just the icon, no bubble
    if (message.messageType == 'namaste') {
      return _buildNamasteMessageTile(message, isOwnMessage, isLastInGroup: isLastInGroup);
    }

    return _SwipeableMessage(
      isOwnMessage: isOwnMessage,
      onSwipe: () => _startReply(message),
      child: Container(
        margin: EdgeInsets.only(
          bottom: isLastInGroup ? 16 : 2,
          left: 4,
          right: 4,
        ),
        child: Column(
          crossAxisAlignment:
              isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Show avatar and name at top of message group
            if (isFirstInGroup) ...[
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: isOwnMessage
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!isOwnMessage) ...[
                      UserAvatar(
                        userId: message.senderId,
                        imageUrl: message.senderAvatar,
                        size: 24,
                        loadFromFirestore: true,
                        nameInitials: message.senderName.isNotEmpty
                            ? message.senderName.substring(0, 1).toUpperCase()
                            : 'U',
                        showBorder: false,
                      ),
                      SizedBox(width: 8),
                      _buildSenderName(
                          message.senderId, message.senderName, false),
                    ],
                    if (isOwnMessage) ...[
                      _buildSenderName(
                          message.senderId, message.senderName, true),
                      SizedBox(width: 8),
                      UserAvatar(
                        userId: message.senderId,
                        imageUrl: message.senderAvatar,
                        size: 24,
                        loadFromFirestore: true,
                        nameInitials: message.senderName.isNotEmpty
                            ? message.senderName.substring(0, 1).toUpperCase()
                            : 'U',
                        showBorder: false,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Message bubble with gestures: long press for options, double tap for ❤️, tap for exact time
            Row(
              mainAxisAlignment:
                  isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Flexible(
                  flex: 4, // Max width 80% of screen
                  child: GestureDetector(
                    onLongPress: () => _showMessageOptions(message, isOwnMessage),
                    onDoubleTap: () => _quickReact(message),
                    onTap: () => _showExactTime(message),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isPending
                            ? (isOwnMessage
                                ? AppTheme.primaryColor.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.9))
                            : (isOwnMessage
                                ? AppTheme.primaryColor
                                : Colors.white),
                        borderRadius: _getBorderRadius(
                            isOwnMessage, isFirstInGroup, isLastInGroup),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildMessageContent(message),
                    ),
                  ),
                ),
              ],
            ),

            // Timestamp and status at bottom of group
            if (isLastInGroup) ...[
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: isOwnMessage
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isOwnMessage) ...[
                      SizedBox(width: 6),
                      _buildMessageStatusIcon(message.status),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Start replying to a message
  void _startReply(ChatMessage message) {
    HapticFeedback.lightImpact();
    setState(() {
      _replyingTo = message;
    });
    _textFieldFocusNode.requestFocus();
  }

  /// Quick react with ❤️ on double tap
  void _quickReact(ChatMessage message) {
    HapticFeedback.mediumImpact();
    _chatService.addReaction(message.id, '❤️');

    // Show brief visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('❤️', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text('Reacted'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 100, left: 80, right: 80),
      ),
    );
  }

  /// Show exact time tooltip on tap
  void _showExactTime(ChatMessage message) {
    final exactTime = DateFormat('EEEE, MMM d, yyyy • h:mm a').format(message.timestamp);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exactTime,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.9),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 100, left: 40, right: 40),
      ),
    );
  }

  Widget _buildSenderName(
      String senderId, String storedName, bool isOwnMessage) {
    // Check if we need to fetch the name dynamically
    bool needsDynamicFetch = storedName.isEmpty ||
        storedName == 'Unknown User' ||
        storedName == 'Unknown';

    if (needsDynamicFetch) {
      return FutureBuilder<String>(
        future: _getUserName(senderId),
        builder: (context, snapshot) {
          String displayName = storedName.isNotEmpty && storedName != 'Unknown'
              ? storedName
              : 'Loading...';

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            displayName = snapshot.data!;
          } else if (snapshot.hasError ||
              (snapshot.hasData && snapshot.data!.isEmpty)) {
            displayName = 'Unknown User';
          }

          return Text(
            displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
              decoration: TextDecoration.none,
            ),
          );
        },
      );
    }

    // Use stored name if it's valid
    return Text(
      storedName,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryColor,
        decoration: TextDecoration.none,
      ),
    );
  }

  Future<String> _getUserName(String userId) async {
    // Check cache first
    if (_senderNameCache.containsKey(userId)) {
      return _senderNameCache[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      String name = 'Unknown User';
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          name = userData['name'] as String? ??
              userData['nickname'] as String? ??
              'Unknown User';
        }
      }

      // Cache the result
      _senderNameCache[userId] = name;
      return name;
    } catch (e) {
      AppLogger.e('Error fetching user name for chat',
          category: LogCategory.ui,
          data: {'userId': userId, 'error': e.toString()});
      return 'Unknown User';
    }
  }

  BorderRadius _getBorderRadius(
      bool isOwnMessage, bool isFirstInGroup, bool isLastInGroup) {
    const double radius = 16.0;
    const double smallRadius = 4.0;

    if (isFirstInGroup && isLastInGroup) {
      // Single message - full rounded
      return BorderRadius.circular(radius);
    } else if (isFirstInGroup) {
      // First in group
      if (isOwnMessage) {
        return BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(smallRadius),
        );
      } else {
        return BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(smallRadius),
          bottomRight: Radius.circular(radius),
        );
      }
    } else if (isLastInGroup) {
      // Last in group
      if (isOwnMessage) {
        return BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(smallRadius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
      } else {
        return BorderRadius.only(
          topLeft: Radius.circular(smallRadius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
      }
    } else {
      // Middle message in group
      if (isOwnMessage) {
        return BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(smallRadius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(smallRadius),
        );
      } else {
        return BorderRadius.only(
          topLeft: Radius.circular(smallRadius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(smallRadius),
          bottomRight: Radius.circular(radius),
        );
      }
    }
  }

  Widget _buildMessageContent(ChatMessage message) {
    final isOwnMessage = message.senderId == _currentUser?.uid;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show reply reference if this message is a reply
        if (message.replyTo != null && message.replyTo!.isNotEmpty)
          _buildReplyReference(message.replyTo!, isOwnMessage),
        _buildMessageText(message),
        if (message.reactions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: _buildReactions(message),
          ),
      ],
    );
  }

  /// Build the reply reference shown inside a message bubble
  Widget _buildReplyReference(String replyToId, bool isOwnMessage) {
    final repliedMessage = _repliedMessagesCache[replyToId];

    return GestureDetector(
      onTap: () => _scrollToMessage(replyToId),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOwnMessage
              ? Colors.white.withValues(alpha: 0.15)
              : AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isOwnMessage
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppTheme.primaryColor.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              repliedMessage?.senderName ?? 'Message',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isOwnMessage
                    ? Colors.white.withValues(alpha: 0.9)
                    : AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 2),
            Text(
              repliedMessage?.content ?? 'Original message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isOwnMessage
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.primaryColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Scroll to a specific message by ID
  void _scrollToMessage(String messageId) {
    // Find the message index
    final index = _allMessages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    HapticFeedback.lightImpact();

    // With reverse: true, calculate position from the end of the list
    // Index 0 in reversed list = newest message = bottom = scroll position 0
    // So position for message at index N = (length - 1 - N) * estimated_height
    final reversedIndex = _allMessages.length - 1 - index;
    final estimatedPosition = reversedIndex * 85.0;
    
    _scrollController.animateTo(
      estimatedPosition.clamp(0, _scrollController.position.maxScrollExtent),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessageText(ChatMessage message) {
    final isOwnMessage = message.senderId == _currentUser?.uid;
    switch (message.messageType) {
      case 'text':
        return _buildLinkifiedText(
          message.content,
          isOwnMessage: isOwnMessage,
        );
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.mediaUrl != null)
              GestureDetector(
                onTap: () => _openImageFullscreen(message.mediaUrl!),
                child: Hero(
                  tag: 'image_${message.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: message.mediaUrl!,
                      width: 200,
                      height: 150,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => ShimmerImagePlaceholder(
                        width: 200,
                        height: 150,
                        borderRadius: 12,
                      ),
                    ),
                  ),
                ),
              ),
            if (message.content.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isOwnMessage
                        ? Colors.white
                        : AppTheme.primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
          ],
        );
      default:
        return Text(
          'Unsupported message type',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }

  /// Build a namaste message tile - just the icon, no card/bubble
  Widget _buildNamasteMessageTile(ChatMessage message, bool isOwnMessage, {bool isLastInGroup = true}) {
    return Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 8,
        left: 4,
        right: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Namaste icon - centered with alignment based on sender
          Row(
            mainAxisAlignment:
                isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showExactTime(message),
                child: Image.asset(
                  'assets/icons/namaste.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) => Text(
                    '🙏',
                    style: TextStyle(fontSize: 40),
                  ),
                ),
              ),
            ],
          ),
          // Timestamp below the icon
          if (isLastInGroup) ...[
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReactions(ChatMessage message) {
    return Wrap(
      spacing: 4,
      children: message.reactions.entries.map((entry) {
        final reaction = entry.value;
        final count =
            message.reactions.values.where((r) => r == reaction).length;
        final hasReacted = message.reactions[_currentUser?.uid] == reaction;

        return GestureDetector(
          onTap: () => _handleReaction(message.id, reaction),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hasReacted
                  ? AppTheme.primaryColor.withValues(alpha: 0.2)
                  : AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$reaction $count',
              style: TextStyle(
                fontSize: 12,
                color: hasReacted 
                    ? AppTheme.primaryColor 
                    : AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _handleReaction(String messageId, String reaction) {
    _chatService.addReaction(messageId, reaction);
  }

  Widget _buildMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const MessageSendingIndicator();
      case MessageStatus.sent:
        return Icon(
          Icons.done, // Single tick
          size: 14,
          color: AppTheme.primaryColor.withValues(alpha: 0.5),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all, // Double tick
          size: 14,
          color: AppTheme.primaryColor.withValues(alpha: 0.5),
        );
    }
  }

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(left: 44, right: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDots(),
                SizedBox(width: 8),
                Text(
                  _typingUsers.length == 1
                      ? '${_typingUsers.first} is typing'
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
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 400),
          margin: EdgeInsets.only(right: 2),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // e.g., "Monday"
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date); // e.g., "Dec 25"
    } else {
      return DateFormat('MMM d, yyyy').format(date); // e.g., "Dec 25, 2024"
    }
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateSeparator(date),
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  /// Show message options on long press
  void _showMessageOptions(ChatMessage message, bool isOwnMessage) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.surfaceDarkColor
              : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Reply option
              _buildOptionTile(
                icon: Icons.reply_rounded,
                label: 'Reply',
                onTap: () {
                  Navigator.pop(context);
                  _startReply(message);
                },
              ),
              if (message.messageType == 'text')
                _buildOptionTile(
                  icon: Icons.copy_rounded,
                  label: 'Copy message',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Message copied'),
                        backgroundColor: AppTheme.primaryColor,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              // Quick reactions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _chatService.addReaction(message.id, emoji);
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(emoji, style: TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (isOwnMessage)
                _buildOptionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete message',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteMessage(message);
                  },
                ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppTheme.errorColor : AppTheme.primaryColor;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _confirmDeleteMessage(ChatMessage message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Message'),
        content: Text('Are you sure you want to delete this message? This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              _chatService.deleteMessage(message.id);
            },
          ),
        ],
      ),
    );
  }

  /// Open fullscreen image viewer
  void _openImageFullscreen(String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullscreenImageViewer(imageUrl: imageUrl),
          );
        },
      ),
    );
  }

  /// Format last seen time for DM header
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(lastSeen);
    }
  }

  /// Build reply preview above input - clean, modern design
  Widget _buildReplyPreview() {
    if (_replyingTo == null) return SizedBox.shrink();

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Color accent bar
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Reply icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.reply_rounded,
              color: AppTheme.primaryColor,
              size: 16,
            ),
          ),
          SizedBox(width: 10),
          // Reply content
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _replyingTo!.senderName,
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _replyingTo!.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.primaryColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Close button
          GestureDetector(
            onTap: _cancelReply,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cancel reply
  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  /// Build text with clickable links
  Widget _buildLinkifiedText(String text, {required bool isOwnMessage}) {
    // URL regex pattern
    final urlPattern = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );

    final matches = urlPattern.allMatches(text);
    
    if (matches.isEmpty) {
      // No links, return simple text
      return Text(
        text,
        style: TextStyle(
          color: isOwnMessage ? Colors.white : AppTheme.primaryColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // Build rich text with clickable links
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the link
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            color: isOwnMessage ? Colors.white : AppTheme.primaryColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ));
      }

      // Add the link
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: isOwnMessage ? Colors.white : AppTheme.primaryColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: isOwnMessage
              ? Colors.white.withValues(alpha: 0.7)
              : AppTheme.primaryColor.withValues(alpha: 0.7),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _openUrl(url),
      ));

      lastEnd = match.end;
    }

    // Add remaining text after last link
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          color: isOwnMessage ? Colors.white : AppTheme.primaryColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// Open URL in browser
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

/// Fullscreen image viewer with pinch-to-zoom
class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullscreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () {
              // TODO: Implement download functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Download coming soon'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            backgroundDecoration: BoxDecoration(color: Colors.transparent),
            loadingBuilder: (context, event) => const Center(
              child: PulsingDots(color: Colors.white, size: 10),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom swipeable message widget with smooth animation
class _SwipeableMessage extends StatefulWidget {
  final Widget child;
  final bool isOwnMessage;
  final VoidCallback onSwipe;

  const _SwipeableMessage({
    required this.child,
    required this.isOwnMessage,
    required this.onSwipe,
  });

  @override
  State<_SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<_SwipeableMessage>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _triggered = false;
  
  static const double _triggerThreshold = 60;
  static const double _maxDrag = 80;

  @override
  Widget build(BuildContext context) {
    // Calculate icon opacity and scale based on drag progress
    final progress = (_dragOffset.abs() / _triggerThreshold).clamp(0.0, 1.0);
    final iconOpacity = progress;
    final iconScale = 0.5 + (progress * 0.5);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          if (widget.isOwnMessage) {
            // Swipe left for own messages
            _dragOffset = (details.delta.dx + _dragOffset).clamp(-_maxDrag, 0);
          } else {
            // Swipe right for others' messages
            _dragOffset = (details.delta.dx + _dragOffset).clamp(0, _maxDrag);
          }

          // Trigger haptic at threshold
          if (!_triggered && _dragOffset.abs() >= _triggerThreshold) {
            _triggered = true;
            HapticFeedback.mediumImpact();
          } else if (_triggered && _dragOffset.abs() < _triggerThreshold) {
            _triggered = false;
          }
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset.abs() >= _triggerThreshold) {
          widget.onSwipe();
        }
        setState(() {
          _dragOffset = 0;
          _triggered = false;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dragOffset = 0;
          _triggered = false;
        });
      },
      child: Stack(
        children: [
          // Reply icon background
          Positioned.fill(
            child: Align(
              alignment: widget.isOwnMessage
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 100),
                  opacity: iconOpacity,
                  child: Transform.scale(
                    scale: iconScale,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _triggered
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.reply_rounded,
                        color: _triggered
                            ? Colors.white
                            : AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Message content
          AnimatedContainer(
            duration: Duration(milliseconds: _dragOffset == 0 ? 200 : 0),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
