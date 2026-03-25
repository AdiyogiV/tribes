import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/services/media/media_upload_helper.dart';
import 'package:aurogram/services/media/voice_recorder_controller.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/chat/mentions_overlay.dart';
import 'package:aurogram/widgets/chat/input_link_preview.dart';
import 'package:aurogram/utils/chat/external_link_utils.dart';

// Conditional imports for thumbnail generation
import 'package:get_thumbnail_video/index.dart'
    if (dart.library.html) 'package:aurogram/platform/video_thumbnail_stub.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart'
    if (dart.library.html) 'package:aurogram/platform/video_thumbnail_stub.dart';
import 'package:aurogram/services/media/video_thumbnail_stub.dart'
    if (dart.library.html) 'package:aurogram/services/media/video_thumbnail_web.dart';

/// Unified chat input area with reply preview, attachment options, and @mentions
class SpaceChatInputArea extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode textFieldFocusNode;
  final ChatMessage? replyingTo;
  final bool isDMConversation;
  final bool namasteSentThisSession;
  final String spaceId;
  final VoidCallback onSendMessage;
  final VoidCallback onSendNamaste;
  final VoidCallback onCancelReply;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<List<String>>? onMentionsChanged;
  final bool isPendingRequest; // Disable input when viewing pending request (recipient)

  /// Callback for optimistic voice message - called immediately when recording stops
  final void Function(ChatMessage message)? onOptimisticVoiceMessage;

  /// Callback to update status of an optimistic message (e.g., on failure)
  final void Function(String messageId, MessageStatus status)?
      onVoiceMessageStatusUpdate;

  const SpaceChatInputArea({
    super.key,
    required this.messageController,
    required this.textFieldFocusNode,
    this.replyingTo,
    required this.isDMConversation,
    required this.namasteSentThisSession,
    required this.spaceId,
    required this.onSendMessage,
    required this.onSendNamaste,
    required this.onCancelReply,
    required this.onTextChanged,
    this.onMentionsChanged,
    this.onOptimisticVoiceMessage,
    this.onVoiceMessageStatusUpdate,
    this.isPendingRequest = false,
  });

  @override
  State<SpaceChatInputArea> createState() => _SpaceChatInputAreaState();
}

class _SpaceChatInputAreaState extends State<SpaceChatInputArea> {
  final ImagePicker _picker = ImagePicker();
  final SpaceChatService _chatService = SpaceChatService();
  final VoiceRecorderController _voiceController = VoiceRecorderController();

  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _showAttachMenu = false;
  late MentionsController _mentionsController;
  StreamSubscription<VoiceRecorderState>? _voiceSubscription;

  // Voice recording UI state (local to widget)
  bool _cancelledByDrag = false;
  double _dragOffset = 0; // For slide-to-cancel

  // Link preview state
  String? _detectedUrl;
  ExternalLinkPreview? _linkPreview;
  bool _isLoadingPreview = false;
  bool _previewDismissed = false;
  Timer? _urlDetectionTimer;

  @override
  void initState() {
    super.initState();
    _mentionsController = MentionsController(
      textController: widget.messageController,
      spaceId: widget.spaceId,
    );
    _mentionsController.setOnStateChanged(() {
      if (mounted) setState(() {});
    });

    // Listen to voice recorder state changes
    _voiceSubscription = _voiceController.stateStream.listen((state) {
      if (mounted) setState(() {});
    });

    // Don't initialize recorder here - it will be initialized lazily when user starts recording
    // This prevents requesting microphone permission immediately when opening a chat

    // Listen for text changes to detect URLs
    widget.messageController.addListener(_onTextChangedForUrlDetection);
  }

  @override
  void dispose() {
    _voiceSubscription?.cancel();
    _urlDetectionTimer?.cancel();
    _mentionsController.dispose();
    widget.messageController.removeListener(_onTextChangedForUrlDetection);
    // Don't dispose the voice controller - it's a singleton
    super.dispose();
  }

  /// Debounced URL detection from text input
  void _onTextChangedForUrlDetection() {
    _urlDetectionTimer?.cancel();

    // Debounce URL detection by 500ms
    _urlDetectionTimer = Timer(const Duration(milliseconds: 500), () {
      _detectAndFetchLinkPreview();
    });
  }

  /// Detect URL in text and fetch preview
  Future<void> _detectAndFetchLinkPreview() async {
    final text = widget.messageController.text;
    final detectedUrl = ExternalLinkUtils.extractFirstExternalLink(text);

    // If no URL found, clear preview
    if (detectedUrl == null) {
      if (_detectedUrl != null || _linkPreview != null) {
        setState(() {
          _detectedUrl = null;
          _linkPreview = null;
          _isLoadingPreview = false;
          _previewDismissed = false;
        });
      }
      return;
    }

    // If same URL and preview was dismissed, don't show again
    if (detectedUrl == _detectedUrl && _previewDismissed) {
      return;
    }

    // If same URL and we already have preview, no need to fetch
    if (detectedUrl == _detectedUrl && _linkPreview != null) {
      return;
    }

    // New URL detected
    setState(() {
      _detectedUrl = detectedUrl;
      _isLoadingPreview = true;
      _previewDismissed = false;
      _linkPreview = null;
    });

    // Fetch preview
    final preview = await ExternalLinkUtils.fetchPreview(detectedUrl);

    // Check if URL is still the same (user might have changed text)
    if (!mounted || _detectedUrl != detectedUrl) return;

    setState(() {
      _linkPreview = preview;
      _isLoadingPreview = false;
    });
  }

  /// Dismiss the link preview
  void _dismissLinkPreview() {
    if (!kIsWeb) HapticFeedback.lightImpact();
    setState(() {
      _previewDismissed = true;
      _linkPreview = null;
    });
  }

  /// Clear link preview state (called when message is sent)
  void _clearLinkPreview() {
    setState(() {
      _detectedUrl = null;
      _linkPreview = null;
      _isLoadingPreview = false;
      _previewDismissed = false;
    });
  }

  /// Handle send message with preview clear
  void _handleSendMessage() {
    _clearLinkPreview();
    widget.onSendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;

    return ListenableBuilder(
      listenable: widget.messageController,
      builder: (context, _) {
        final hasText = widget.messageController.text.trim().isNotEmpty;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mentions suggestions overlay
              MentionsOverlay(
                controller: _mentionsController,
                maxHeight: 180,
              ),

              // Link preview card (shown when URL detected)
              if ((_linkPreview != null || _isLoadingPreview) &&
                  !_previewDismissed)
                InputLinkPreview(
                  preview: _linkPreview,
                  isLoading: _isLoadingPreview,
                  isDark: isDark,
                  onDismiss: _dismissLinkPreview,
                ),

              // Upload progress indicator
              if (_isUploading) _UploadProgressBar(progress: _uploadProgress),

              // Attachment menu (expandable)
              if (_showAttachMenu)
                _AttachmentMenu(
                  isDark: isDark,
                  onCamera: _pickFromCamera,
                  onGallery: _pickFromGallery,
                  onVideo: _pickVideo,
                  onClose: () => setState(() => _showAttachMenu = false),
                ),

              // Main input area
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    elevation: 4,
                    color: Colors.transparent,
                    shadowColor: Colors.black.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              barBase.withValues(alpha: isDark ? 0.85 : 0.90),
                              barBase.withValues(alpha: isDark ? 0.80 : 0.85),
                            ],
                          ),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : barBase.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Reply preview
                            if (widget.replyingTo != null)
                              _InlineReplyPreview(
                                replyingTo: widget.replyingTo!,
                                isDark: isDark,
                                onCancel: widget.onCancelReply,
                              ),
                            // Input row with hold-to-record mic
                            SizedBox(
                              height: 70,
                              child: Row(
                                children: [
                                  // Attachment button (hidden during recording)
                                  if (!_voiceController.isRecording)
                                    _AttachButton(
                                      isExpanded: _showAttachMenu,
                                      isUploading: _isUploading,
                                      onTap: _isUploading
                                          ? null
                                          : _toggleAttachMenu,
                                    ),
                                  if (_voiceController.isRecording)
                                    const SizedBox(width: 12),
                                  const SizedBox(width: 8),
                                  // Text input or Recording indicator
                                  Expanded(
                                    child: _voiceController.isRecording
                                        ? _buildRecordingRow()
                                        : KeyboardListener(
                                            focusNode:
                                                FocusNode(skipTraversal: true),
                                            onKeyEvent: kIsWeb
                                                ? (event) {
                                                    // Web: Enter sends, Shift+Enter adds newline
                                                    if (event is KeyDownEvent &&
                                                        event.logicalKey ==
                                                            LogicalKeyboardKey
                                                                .enter &&
                                                        !HardwareKeyboard
                                                            .instance
                                                            .isShiftPressed) {
                                                      if (hasText) {
                                                        _handleSendMessage();
                                                      }
                                                    }
                                                  }
                                                : null,
                                            child: TextField(
                                              controller:
                                                  widget.messageController,
                                              focusNode:
                                                  widget.textFieldFocusNode,
                                              enabled: !widget.isPendingRequest,
                                              decoration: InputDecoration(
                                                hintText: widget.isPendingRequest
                                                    ? 'Accept the request to send messages'
                                                    : widget.replyingTo !=
                                                            null
                                                        ? 'Reply to ${widget.replyingTo!.senderName}...'
                                                        : kIsWeb
                                                            ? 'Type message (Shift+Enter for new line)'
                                                            : 'Type message',
                                                hintStyle: TextStyle(
                                                  color: AppTheme.primaryColor
                                                      .withValues(alpha: widget.isPendingRequest ? 0.4 : 0.6),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                filled: false,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 0),
                                                isDense: true,
                                              ),
                                              style: TextStyle(
                                                color: AppTheme.primaryColor
                                                    .withValues(alpha: widget.isPendingRequest ? 0.5 : 0.85),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: null,
                                              // Web: allow newlines; Mobile: send button on keyboard
                                              textInputAction: kIsWeb
                                                  ? TextInputAction.newline
                                                  : TextInputAction.send,
                                              textCapitalization:
                                                  TextCapitalization.sentences,
                                              autofocus: false,
                                              enableInteractiveSelection: !widget.isPendingRequest,
                                              onChanged: widget.onTextChanged,
                                              // Mobile: onSubmitted sends; Web: handled by KeyboardListener
                                              onSubmitted: kIsWeb
                                                  ? null
                                                  : (hasText
                                                      ? (_) =>
                                                          _handleSendMessage()
                                                      : null),
                                              onTap: () {
                                                if (_showAttachMenu) {
                                                  setState(() =>
                                                      _showAttachMenu = false);
                                                }
                                                if (!widget.textFieldFocusNode
                                                    .hasFocus) {
                                                  widget.textFieldFocusNode
                                                      .requestFocus();
                                                }
                                              },
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Send button or Mic (hold-to-record)
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: widget.isPendingRequest
                                        ? IconButton(
                                            onPressed: null,
                                            icon: Icon(
                                              CupertinoIcons.paperplane_fill,
                                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                              size: 22,
                                            ),
                                          )
                                        : hasText
                                            ? IconButton(
                                                onPressed: _handleSendMessage,
                                                icon: Icon(
                                                  CupertinoIcons.paperplane_fill,
                                                  color: AppTheme.primaryColor,
                                                  size: 22,
                                                ),
                                              )
                                            : GestureDetector(
                                                onLongPressStart: (_) =>
                                                    _onRecordStart(),
                                                onLongPressEnd: (_) =>
                                                    _onRecordEnd(),
                                                onLongPressMoveUpdate:
                                                    _onRecordDrag,
                                                onTap: () =>
                                                    _showError('Hold to record'),
                                                child: Container(
                                                  width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    _voiceController.isRecording
                                                        ? AppTheme.errorColor
                                                        : Colors.transparent,
                                              ),
                                              child: Icon(
                                                CupertinoIcons.mic_fill,
                                                color: _voiceController
                                                        .isRecording
                                                    ? Colors.white
                                                    : AppTheme.primaryColor
                                                        .withValues(alpha: 0.6),
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleAttachMenu() {
    if (!kIsWeb) HapticFeedback.lightImpact();
    setState(() => _showAttachMenu = !_showAttachMenu);
  }

  Future<void> _pickFromCamera() async {
    setState(() => _showAttachMenu = false);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo != null) {
        await _uploadMedia(photo, 'image');
      }
    } catch (e) {
      AppLogger.e('Error picking from camera',
          category: LogCategory.media, error: e);
      _showError('Could not access camera');
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _showAttachMenu = false);

    try {
      final XFile? media = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (media != null) {
        await _uploadMedia(media, 'image');
      }
    } catch (e) {
      AppLogger.e('Error picking from gallery',
          category: LogCategory.media, error: e);
      _showError('Could not access gallery');
    }
  }

  Future<void> _pickVideo() async {
    setState(() => _showAttachMenu = false);

    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        await _uploadMedia(video, 'video');
      }
    } catch (e) {
      AppLogger.e('Error picking video', category: LogCategory.media, error: e);
      _showError('Could not access video');
    }
  }

  Future<void> _uploadMedia(XFile file, String messageType) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.name.split('.').last;
      final storagePath = 'chat_media/${widget.spaceId}/$timestamp.$extension';

      String? thumbnailUrl;

      // Generate and upload thumbnail for videos
      if (messageType == 'video') {
        try {
          final thumbStoragePath =
              'chat_media/${widget.spaceId}/${timestamp}_thumb.jpg';

          if (kIsWeb) {
            // Web: Generate thumbnail using HTML5 canvas
            final thumbnailBytes =
                await VideoThumbnailWeb.generateThumbnailFromFile(file);
            if (thumbnailBytes != null) {
              thumbnailUrl = await MediaUploadHelper.uploadBytes(
                bytes: thumbnailBytes,
                storagePath: thumbStoragePath,
                contentType: 'image/jpeg',
              );
            }
          } else {
            // Mobile: Generate thumbnail using native package
            final thumbnailPath = await _generateVideoThumbnail(file.path);
            if (thumbnailPath != null) {
              thumbnailUrl = await MediaUploadHelper.uploadFromPath(
                filePath: thumbnailPath,
                storagePath: thumbStoragePath,
              );
            }
          }
        } catch (e) {
          AppLogger.w('Could not generate thumbnail: $e',
              category: LogCategory.media);
          // Continue without thumbnail
        }
      }

      // Upload main media with progress tracking
      final downloadUrl = await MediaUploadHelper.uploadXFile(
        xFile: file,
        storagePath: storagePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      if (downloadUrl != null) {
        // Send media message with thumbnail
        await _chatService.sendMediaMessage(
          widget.spaceId,
          downloadUrl,
          messageType,
          thumbnailUrl: thumbnailUrl,
          replyTo: widget.replyingTo?.id,
        );

        // Clear reply if there was one
        if (widget.replyingTo != null) {
          widget.onCancelReply();
        }
      } else {
        _showError('Failed to upload media');
      }
    } catch (e) {
      AppLogger.e('Error uploading media',
          category: LogCategory.media, error: e);
      _showError('Failed to send media');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  /// Generate thumbnail from video (mobile only)
  Future<String?> _generateVideoThumbnail(String videoPath) async {
    if (kIsWeb) return null;

    try {
      final dynamic result = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 85,
        timeMs: 1000,
      );

      if (result == null) return null;
      if (result is String) return result;
      // Handle XFile or other types
      final path = result.path;
      return path is String ? path : path.toString();
    } catch (e) {
      AppLogger.e('Error generating video thumbnail: $e',
          category: LogCategory.media);
      return null;
    }
  }

  // === Voice Recording Methods (using singleton controller) ===

  Future<void> _onRecordStart() async {
    AppLogger.i('Voice recording start requested',
        category: LogCategory.voice, data: {'isWeb': kIsWeb});

    // Haptic feedback (no-op on web)
    if (!kIsWeb) HapticFeedback.mediumImpact();

    setState(() {
      _showAttachMenu = false;
      _dragOffset = 0;
      _cancelledByDrag = false;
    });

    final started = await _voiceController.startRecording();
    AppLogger.i('Voice recording started: $started',
        category: LogCategory.voice);

    if (!started && mounted) {
      _showError('Could not start recording');
    }
  }

  Future<void> _onRecordEnd() async {
    AppLogger.i('Voice recording end requested',
        category: LogCategory.voice,
        data: {'isWeb': kIsWeb, 'cancelledByDrag': _cancelledByDrag});

    if (_cancelledByDrag) {
      setState(() {
        _dragOffset = 0;
        _cancelledByDrag = false;
      });
      return;
    }

    final recordingPath = await _voiceController.stopRecording();
    final duration = _voiceController.duration;
    final recordingBytes = _voiceController.recordingBytes;

    AppLogger.i('Voice recording stopped', category: LogCategory.voice, data: {
      'path': recordingPath,
      'duration': duration.inSeconds,
      'hasBytes': recordingBytes != null,
      'bytesLength': recordingBytes?.length ?? 0,
    });

    setState(() => _dragOffset = 0);

    if (recordingPath == null) {
      if (mounted) _showError('Recording too short');
      return;
    }

    // Send the voice message
    await _sendVoiceMessage(recordingPath, duration);
  }

  void _onRecordDrag(LongPressMoveUpdateDetails details) {
    if (!_voiceController.isRecording) return;

    final dx = details.offsetFromOrigin.dx;
    setState(() {
      _dragOffset = dx.clamp(-150.0, 0.0);
    });

    // Cancel if dragged far enough left
    if (dx < -100 && !_cancelledByDrag) {
      _cancelledByDrag = true;
      if (!kIsWeb) HapticFeedback.mediumImpact();
      _voiceController.cancelRecording();
      if (mounted) {
        setState(() => _dragOffset = 0);
      }
    }
  }

  Future<void> _sendVoiceMessage(String filePath, Duration duration) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError('Please sign in to send messages');
      return;
    }

    // Get recording bytes for web
    final recordingBytes = _voiceController.recordingBytes;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempId = 'sending_voice_$timestamp';

    // Get user info for optimistic message
    String userName = 'You';
    String? userAvatar;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data();
        userName = data?['name'] ?? data?['nickname'] ?? 'You';
        userAvatar = data?['displayPicture'];
      }
    } catch (e) {
      // Use default values
    }

    // Create optimistic message immediately
    final optimisticMessage = ChatMessage(
      id: tempId,
      spaceId: widget.spaceId,
      senderId: currentUser.uid,
      senderName: userName,
      senderAvatar: userAvatar,
      content: '',
      messageType: 'audio',
      mediaUrl: kIsWeb ? null : filePath, // No local file on web
      fileSize: duration.inSeconds,
      replyTo: widget.replyingTo?.id,
      reactions: {},
      readBy: [currentUser.uid],
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    // Notify parent immediately - message appears in UI now
    widget.onOptimisticVoiceMessage?.call(optimisticMessage);

    // Clear reply if any
    if (widget.replyingTo != null) {
      widget.onCancelReply();
    }

    if (!kIsWeb) HapticFeedback.lightImpact();
    AppLogger.i('Voice message optimistic - uploading in background',
        category: LogCategory.voice,
        data: {
          'duration': duration.inSeconds,
          'tempId': tempId,
          'isWeb': kIsWeb
        });

    // Upload in background (non-blocking)
    _uploadVoiceMessageInBackground(
      filePath: filePath,
      recordingBytes: recordingBytes,
      duration: duration,
      tempId: tempId,
      timestamp: timestamp,
    );
  }

  /// Upload voice message in background after optimistic message is shown
  Future<void> _uploadVoiceMessageInBackground({
    required String filePath,
    Uint8List? recordingBytes,
    required Duration duration,
    required String tempId,
    required int timestamp,
  }) async {
    try {
      String? downloadUrl;

      if (kIsWeb && recordingBytes != null) {
        // Web: Upload bytes directly with .webm extension
        final storagePath =
            'chat_media/${widget.spaceId}/voice_$timestamp.webm';
        downloadUrl = await MediaUploadHelper.uploadBytes(
          bytes: recordingBytes,
          storagePath: storagePath,
          contentType: 'audio/webm',
        );
      } else {
        // Mobile: Upload from file path with .m4a extension
        final storagePath = 'chat_media/${widget.spaceId}/voice_$timestamp.m4a';
        downloadUrl = await MediaUploadHelper.uploadFromPath(
          filePath: filePath,
          storagePath: storagePath,
        );
      }

      if (downloadUrl != null) {
        await _chatService.sendMediaMessage(
          widget.spaceId,
          downloadUrl,
          'audio',
          fileSize: duration.inSeconds,
        );

        AppLogger.i('Voice message uploaded successfully',
            category: LogCategory.voice,
            data: {'duration': duration.inSeconds, 'isWeb': kIsWeb});
      } else {
        // Upload failed - notify parent to show retry
        widget.onVoiceMessageStatusUpdate?.call(tempId, MessageStatus.sending);
        _showError('Failed to upload voice message');
      }
    } catch (e) {
      AppLogger.e('Failed to upload voice: $e', category: LogCategory.voice);
      // Notify parent to show retry option
      widget.onVoiceMessageStatusUpdate?.call(tempId, MessageStatus.sending);
      _showError('Failed to send voice message');
    }
  }

  /// Build the recording row shown during voice recording
  Widget _buildRecordingRow() {
    final duration = _voiceController.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Calculate opacity for slide-to-cancel (fades as you drag)
    final cancelOpacity = (_dragOffset.abs() / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        // Slide to cancel indicator (animated)
        Expanded(
          child: Transform.translate(
            offset: Offset(_dragOffset * 0.5, 0),
            child: Row(
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  color: AppTheme.errorColor
                      .withValues(alpha: 0.4 + cancelOpacity * 0.5),
                  size: 20,
                ),
                const SizedBox(width: 2),
                Text(
                  'Slide to cancel',
                  style: TextStyle(
                    color: AppTheme.primaryColor
                        .withValues(alpha: 0.4 + cancelOpacity * 0.3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Timer + Recording indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: TextStyle(
                color: AppTheme.errorColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Upload progress bar
class _UploadProgressBar extends StatelessWidget {
  final double progress;

  const _UploadProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Uploading... ${progress.toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attachment button with + icon
class _AttachButton extends StatelessWidget {
  final bool isExpanded;
  final bool isUploading;
  final VoidCallback? onTap;

  const _AttachButton({
    required this.isExpanded,
    required this.isUploading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isExpanded
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedRotation(
          turns: isExpanded ? 0.125 : 0, // 45 degrees
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.add_rounded,
            color: isUploading
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : AppTheme.primaryColor,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Attachment menu with camera, gallery, and video options
class _AttachmentMenu extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onVideo;
  final VoidCallback onClose;

  const _AttachmentMenu({
    required this.isDark,
    required this.onCamera,
    required this.onGallery,
    required this.onVideo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardDarkColor.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AttachOption(
            icon: CupertinoIcons.camera_fill,
            label: 'Camera',
            onTap: onCamera,
          ),
          _AttachOption(
            icon: CupertinoIcons.photo_on_rectangle,
            label: 'Gallery',
            onTap: onGallery,
          ),
          _AttachOption(
            icon: CupertinoIcons.videocam_fill,
            label: 'Video',
            onTap: onVideo,
          ),
        ],
      ),
    );
  }
}

/// Single attachment option button
class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (!kIsWeb) HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline reply preview shown inside the input area
class _InlineReplyPreview extends StatelessWidget {
  final ChatMessage replyingTo;
  final bool isDark;
  final VoidCallback onCancel;

  const _InlineReplyPreview({
    required this.replyingTo,
    required this.isDark,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Accent line
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          // Reply content
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: replyingTo.senderName,
                    style: TextStyle(
                      color: AppTheme.primaryColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const TextSpan(
                    text: '  ',
                    style: TextStyle(fontSize: 13),
                  ),
                  TextSpan(
                    text: replyingTo.content,
                    style: TextStyle(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Close button
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(
                Icons.close_rounded,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing red dot for recording indicator
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.errorColor.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}
