import 'dart:ui';
import 'dart:async';
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
import 'package:aurogram/pages/spaces/widgets/input/chat_attachment_picker.dart';
import 'package:aurogram/pages/spaces/widgets/input/chat_reply_preview.dart';
import 'package:aurogram/pages/spaces/widgets/input/chat_recording_indicator.dart';

// Conditional imports for thumbnail generation
import 'package:get_thumbnail_video/index.dart'
    if (dart.library.html) 'package:aurogram/platform/video_thumbnail_stub.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart'
    if (dart.library.html) 'package:aurogram/platform/video_thumbnail_stub.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';
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
  final bool isPendingRequest;

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
  double _dragOffset = 0;

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

    _voiceSubscription = _voiceController.stateStream.listen((state) {
      if (mounted) setState(() {});
    });

    widget.messageController.addListener(_onTextChangedForUrlDetection);
  }

  @override
  void dispose() {
    _voiceSubscription?.cancel();
    _urlDetectionTimer?.cancel();
    _mentionsController.dispose();
    widget.messageController.removeListener(_onTextChangedForUrlDetection);
    super.dispose();
  }

  /// Debounced URL detection from text input
  void _onTextChangedForUrlDetection() {
    _urlDetectionTimer?.cancel();
    _urlDetectionTimer = Timer(const Duration(milliseconds: 500), () {
      _detectAndFetchLinkPreview();
    });
  }

  /// Detect URL in text and fetch preview
  Future<void> _detectAndFetchLinkPreview() async {
    final text = widget.messageController.text;
    final detectedUrl = ExternalLinkUtils.extractFirstExternalLink(text);

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

    if (detectedUrl == _detectedUrl && _previewDismissed) return;
    if (detectedUrl == _detectedUrl && _linkPreview != null) return;

    setState(() {
      _detectedUrl = detectedUrl;
      _isLoadingPreview = true;
      _previewDismissed = false;
      _linkPreview = null;
    });

    final preview = await ExternalLinkUtils.fetchPreview(detectedUrl);
    if (!mounted || _detectedUrl != detectedUrl) return;

    setState(() {
      _linkPreview = preview;
      _isLoadingPreview = false;
    });
  }

  void _dismissLinkPreview() {
    if (!kIsWeb) HapticFeedback.lightImpact();
    setState(() {
      _previewDismissed = true;
      _linkPreview = null;
    });
  }

  void _clearLinkPreview() {
    setState(() {
      _detectedUrl = null;
      _linkPreview = null;
      _isLoadingPreview = false;
      _previewDismissed = false;
    });
  }

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
              MentionsOverlay(
                controller: _mentionsController,
                maxHeight: 180,
              ),

              if ((_linkPreview != null || _isLoadingPreview) &&
                  !_previewDismissed)
                InputLinkPreview(
                  preview: _linkPreview,
                  isLoading: _isLoadingPreview,
                  isDark: isDark,
                  onDismiss: _dismissLinkPreview,
                ),

              if (_isUploading) UploadProgressBar(progress: _uploadProgress),

              if (_showAttachMenu)
                AttachmentMenu(
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
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
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
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
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
                            if (widget.replyingTo != null)
                              InlineReplyPreview(
                                replyingTo: widget.replyingTo!,
                                isDark: isDark,
                                onCancel: widget.onCancelReply,
                              ),
                            SizedBox(
                              height: 70,
                              child: Row(
                                children: [
                                  if (!_voiceController.isRecording)
                                    AttachButton(
                                      isExpanded: _showAttachMenu,
                                      isUploading: _isUploading,
                                      onTap: _isUploading
                                          ? null
                                          : _toggleAttachMenu,
                                    ),
                                  if (_voiceController.isRecording)
                                    const SizedBox(width: AppDimensions.spacingMd),
                                  const SizedBox(width: AppDimensions.spacingSm),
                                  Expanded(
                                    child: _voiceController.isRecording
                                        ? _buildRecordingRow()
                                        : KeyboardListener(
                                            focusNode:
                                                FocusNode(skipTraversal: true),
                                            onKeyEvent: kIsWeb
                                                ? (event) {
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
                                                    : widget.replyingTo != null
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
                                              textInputAction: kIsWeb
                                                  ? TextInputAction.newline
                                                  : TextInputAction.send,
                                              textCapitalization:
                                                  TextCapitalization.sentences,
                                              autofocus: false,
                                              enableInteractiveSelection: !widget.isPendingRequest,
                                              onChanged: widget.onTextChanged,
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
                                  const SizedBox(width: AppDimensions.spacingXs),
                                  _buildSendOrMicButton(hasText),
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

  Widget _buildSendOrMicButton(bool hasText) {
    return SizedBox(
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
                  onLongPressStart: (_) => _onRecordStart(),
                  onLongPressEnd: (_) => _onRecordEnd(),
                  onLongPressMoveUpdate: _onRecordDrag,
                  onTap: () => _showError('Hold to record'),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _voiceController.isRecording
                          ? AppTheme.errorColor
                          : Colors.transparent,
                    ),
                    child: Icon(
                      CupertinoIcons.mic_fill,
                      color: _voiceController.isRecording
                          ? Colors.white
                          : AppTheme.primaryColor.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ),
                ),
    );
  }

  void _toggleAttachMenu() {
    if (!kIsWeb) HapticFeedback.lightImpact();
    setState(() => _showAttachMenu = !_showAttachMenu);
  }

  // ===== Media Picking =====

  Future<void> _pickFromCamera() async {
    setState(() => _showAttachMenu = false);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (photo != null) await _uploadMedia(photo, 'image');
    } catch (e) {
      AppLogger.e('Error picking from camera', category: LogCategory.media, error: e);
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
      if (media != null) await _uploadMedia(media, 'image');
    } catch (e) {
      AppLogger.e('Error picking from gallery', category: LogCategory.media, error: e);
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
      if (video != null) await _uploadMedia(video, 'video');
    } catch (e) {
      AppLogger.e('Error picking video', category: LogCategory.media, error: e);
      _showError('Could not access video');
    }
  }

  Future<void> _uploadMedia(XFile file, String messageType) async {
    setState(() { _isUploading = true; _uploadProgress = 0; });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.name.split('.').last;
      final storagePath = 'chat_media/${widget.spaceId}/$timestamp.$extension';

      String? thumbnailUrl;

      if (messageType == 'video') {
        try {
          final thumbStoragePath =
              'chat_media/${widget.spaceId}/${timestamp}_thumb.jpg';
          if (kIsWeb) {
            final thumbnailBytes =
                await VideoThumbnailWeb.generateThumbnailFromFile(file);
            if (thumbnailBytes != null) {
              thumbnailUrl = await MediaUploadHelper.uploadBytes(
                bytes: thumbnailBytes, storagePath: thumbStoragePath, contentType: 'image/jpeg',
              );
            }
          } else {
            final thumbnailPath = await _generateVideoThumbnail(file.path);
            if (thumbnailPath != null) {
              thumbnailUrl = await MediaUploadHelper.uploadFromPath(
                filePath: thumbnailPath, storagePath: thumbStoragePath,
              );
            }
          }
        } catch (e) {
          AppLogger.w('Could not generate thumbnail: $e', category: LogCategory.media);
        }
      }

      final downloadUrl = await MediaUploadHelper.uploadXFile(
        xFile: file, storagePath: storagePath,
        onProgress: (progress) { if (mounted) setState(() => _uploadProgress = progress); },
      );

      if (downloadUrl != null) {
        await _chatService.sendMediaMessage(widget.spaceId, downloadUrl, messageType,
            thumbnailUrl: thumbnailUrl, replyTo: widget.replyingTo?.id);
        if (widget.replyingTo != null) widget.onCancelReply();
      } else {
        _showError('Failed to upload media');
      }
    } catch (e) {
      AppLogger.e('Error uploading media', category: LogCategory.media, error: e);
      _showError('Failed to send media');
    } finally {
      if (mounted) setState(() { _isUploading = false; _uploadProgress = 0; });
    }
  }

  Future<String?> _generateVideoThumbnail(String videoPath) async {
    if (kIsWeb) return null;
    try {
      final dynamic result = await VideoThumbnail.thumbnailFile(
        video: videoPath, imageFormat: ImageFormat.JPEG, maxWidth: 512, quality: 85, timeMs: 1000,
      );
      if (result == null) return null;
      if (result is String) return result;
      final path = result.path;
      return path is String ? path : path.toString();
    } catch (e) {
      AppLogger.e('Error generating video thumbnail: $e', category: LogCategory.media);
      return null;
    }
  }

  // ===== Voice Recording =====

  Future<void> _onRecordStart() async {
    if (!kIsWeb) HapticFeedback.mediumImpact();
    setState(() { _showAttachMenu = false; _dragOffset = 0; _cancelledByDrag = false; });

    final started = await _voiceController.startRecording();
    if (!started && mounted) _showError('Could not start recording');
  }

  Future<void> _onRecordEnd() async {
    if (_cancelledByDrag) {
      setState(() { _dragOffset = 0; _cancelledByDrag = false; });
      return;
    }

    final recordingPath = await _voiceController.stopRecording();
    final duration = _voiceController.duration;
    setState(() => _dragOffset = 0);

    if (recordingPath == null) {
      if (mounted) _showError('Recording too short');
      return;
    }
    await _sendVoiceMessage(recordingPath, duration);
  }

  void _onRecordDrag(LongPressMoveUpdateDetails details) {
    if (!_voiceController.isRecording) return;
    final dx = details.offsetFromOrigin.dx;
    setState(() { _dragOffset = dx.clamp(-150.0, 0.0); });

    if (dx < -100 && !_cancelledByDrag) {
      _cancelledByDrag = true;
      if (!kIsWeb) HapticFeedback.mediumImpact();
      _voiceController.cancelRecording();
      if (mounted) setState(() => _dragOffset = 0);
    }
  }

  Future<void> _sendVoiceMessage(String filePath, Duration duration) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) { _showError('Please sign in to send messages'); return; }

    final recordingBytes = _voiceController.recordingBytes;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempId = 'sending_voice_$timestamp';

    String userName = 'You';
    String? userAvatar;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        userName = data?['name'] ?? data?['nickname'] ?? 'You';
        userAvatar = data?['displayPicture'];
      }
    } catch (e) { /* Use default values */ }

    final optimisticMessage = ChatMessage(
      id: tempId, spaceId: widget.spaceId, senderId: currentUser.uid,
      senderName: userName, senderAvatar: userAvatar, content: '',
      messageType: 'audio', mediaUrl: kIsWeb ? null : filePath,
      fileSize: duration.inSeconds, replyTo: widget.replyingTo?.id,
      reactions: {}, readBy: [currentUser.uid],
      timestamp: DateTime.now(), status: MessageStatus.sending,
    );

    widget.onOptimisticVoiceMessage?.call(optimisticMessage);
    if (widget.replyingTo != null) widget.onCancelReply();
    if (!kIsWeb) HapticFeedback.lightImpact();

    _uploadVoiceMessageInBackground(
      filePath: filePath, recordingBytes: recordingBytes,
      duration: duration, tempId: tempId, timestamp: timestamp,
    );
  }

  Future<void> _uploadVoiceMessageInBackground({
    required String filePath, Uint8List? recordingBytes,
    required Duration duration, required String tempId, required int timestamp,
  }) async {
    try {
      String? downloadUrl;
      if (kIsWeb && recordingBytes != null) {
        final storagePath = 'chat_media/${widget.spaceId}/voice_$timestamp.webm';
        downloadUrl = await MediaUploadHelper.uploadBytes(
          bytes: recordingBytes, storagePath: storagePath, contentType: 'audio/webm',
        );
      } else {
        final storagePath = 'chat_media/${widget.spaceId}/voice_$timestamp.m4a';
        downloadUrl = await MediaUploadHelper.uploadFromPath(
          filePath: filePath, storagePath: storagePath,
        );
      }

      if (downloadUrl != null) {
        await _chatService.sendMediaMessage(
          widget.spaceId, downloadUrl, 'audio', fileSize: duration.inSeconds,
        );
      } else {
        widget.onVoiceMessageStatusUpdate?.call(tempId, MessageStatus.sending);
        _showError('Failed to upload voice message');
      }
    } catch (e) {
      AppLogger.e('Failed to upload voice: $e', category: LogCategory.voice);
      widget.onVoiceMessageStatusUpdate?.call(tempId, MessageStatus.sending);
      _showError('Failed to send voice message');
    }
  }

  Widget _buildRecordingRow() {
    final duration = _voiceController.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
    final cancelOpacity = (_dragOffset.abs() / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: Transform.translate(
            offset: Offset(_dragOffset * 0.5, 0),
            child: Row(
              children: [
                Icon(Icons.chevron_left_rounded,
                    color: AppTheme.errorColor.withValues(alpha: 0.4 + cancelOpacity * 0.5), size: 20),
                const SizedBox(width: AppDimensions.spacingXxs),
                Text('Slide to cancel', style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4 + cancelOpacity * 0.3),
                    fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulsingDot(),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(timeStr, style: TextStyle(
                color: AppTheme.errorColor, fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(width: AppDimensions.spacingSm),
      ],
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showCustomSnackBar(context, message: message, backgroundColor: AppTheme.errorColor, duration: const Duration(seconds: 3));
  }
}
