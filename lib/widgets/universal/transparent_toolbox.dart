import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/services/audio_input_service.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Universal transparent toolbox with glass blur effect.
/// Matches the tab bar styling for consistency across the app.
///
/// Use this widget for all bottom toolbar/input needs:
/// - TransparentToolbox.search() for search fields
/// - TransparentToolbox.chat() for chat input
/// - TransparentToolbox.astroChat() for astrology chat with cow icon
/// - TransparentToolbox.actions() for action buttons
/// - TransparentToolbox.button() for action buttons like Save/Continue
/// - TransparentToolbox.input() for text input fields like name/phone entry
/// - TransparentToolbox.simple() for simple text/icon content
/// - TransparentToolbox(content: ...) for fully custom content
///
/// For cards that match this style, use TransparentToolbox.buildCard() helper.
class TransparentToolbox extends StatelessWidget {
  final Widget content;
  final EdgeInsets padding;
  final double height;

  const TransparentToolbox({
    super.key,
    required this.content,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10),
    this.height = 70,
  });

  // ============================================
  // LAYOUT CONSTANTS
  // ============================================

  /// Standard horizontal padding inside toolbox
  static const double toolboxHorizontalPadding = 16.0;

  /// Standard card content padding
  static const EdgeInsets cardContentPadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  /// Standard border radius for all toolbox-style widgets (same as cards)
  static double get borderRadius => AppHeaderStyle.cardBorderRadius;

  /// Creates a search toolbox with search icon and text input
  static Widget search({
    required TextEditingController searchController,
    required FocusNode focusNode,
    required Function(String) onSearchChanged,
    String hintText = 'Search',
  }) {
    return TransparentToolbox(
      content: _SearchContent(
        searchController: searchController,
        focusNode: focusNode,
        onSearchChanged: onSearchChanged,
        hintText: hintText,
      ),
    );
  }

  /// Creates a chat input toolbox with text field and send button
  /// Optionally includes a namaste button for DM conversations
  static Widget chat({
    required TextEditingController messageController,
    required FocusNode focusNode,
    required VoidCallback onSend,
    required Function(String) onChanged,
    String hintText = 'Type message',
    bool canSend = false,
    // Namaste button support for DM chats
    VoidCallback? onNamaste,
    bool showNamasteButton = false,
  }) {
    return TransparentToolbox(
      content: _ChatContent(
        messageController: messageController,
        focusNode: focusNode,
        onSend: onSend,
        onChanged: onChanged,
        hintText: hintText,
        canSend: canSend,
        onNamaste: onNamaste,
        showNamasteButton: showNamasteButton,
      ),
    );
  }

  /// Creates an astrology-themed chat input with cow icon
  /// Supports optional voice input when [enableVoice] is true
  static Widget astroChat({
    required TextEditingController messageController,
    required FocusNode focusNode,
    required VoidCallback onSend,
    String hintText = 'Ask anything',
    bool enableVoice = false,
    VoidCallback? onMicPressed,
  }) {
    return TransparentToolbox(
      content: _AstroChatContent(
        messageController: messageController,
        focusNode: focusNode,
        onSend: onSend,
        hintText: hintText,
        enableVoice: enableVoice,
        onMicPressed: onMicPressed,
      ),
    );
  }

  /// Creates a toolbox with custom action buttons
  static Widget actions({
    required List<Widget> actions,
    MainAxisAlignment alignment = MainAxisAlignment.spaceEvenly,
  }) {
    return TransparentToolbox(
      content: Row(
        mainAxisAlignment: alignment,
        children: actions,
      ),
    );
  }

  /// Creates a simple toolbox with text and optional trailing widget
  static Widget simple({
    String? text,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return TransparentToolbox(
      content: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 12),
            ],
            if (text != null)
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  /// Creates a button-style toolbox (for Save, Continue, Send, etc.)
  /// [leadingIcon] - optional icon to show before the text
  /// [leadingIconColor] - custom color for the leading icon
  static Widget button({
    required String text,
    required VoidCallback? onTap,
    IconData? icon,
    IconData? leadingIcon,
    Color? leadingIconColor,
    bool isLoading = false,
    bool enabled = true,
  }) {
    final isEnabled = enabled && !isLoading && onTap != null;

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: TransparentToolbox(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                color: leadingIconColor ?? AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                isLoading ? '${text.replaceAll('...', '')}...' : text,
                style: TextStyle(
                  color: isEnabled
                      ? AppTheme.primaryColor.withValues(alpha: 0.85)
                      : AppTheme.primaryColor.withValues(alpha: 0.4),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isLoading)
              const InlineShimmerLoader(size: 20)
            else
              Icon(
                icon ?? CupertinoIcons.arrow_right,
                color: isEnabled
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.4),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  /// Creates an input-style toolbox (for name entry, phone entry, etc.)
  static Widget input({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    String hintText = '',
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
    Function(String)? onChanged,
    VoidCallback? onSubmitted,
    int maxLines = 1,
  }) {
    return TransparentToolbox(
      content: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: hintTextStyle,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: inputContentPadding,
                isDense: true,
              ),
              style: inputTextStyle,
              onChanged: onChanged,
              onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a card widget matching TransparentToolbox style.
  /// Use this for profile cards, settings cards, etc.
  static Widget buildCard({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = cardContentPadding,
    EdgeInsets? margin,
    VoidCallback? onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    Widget card = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppHeaderStyle.cardGradientColors(isDark, barBase),
          ),
          boxShadow: AppHeaderStyle.cardBoxShadow(isDark),
          border: AppHeaderStyle.cardBorder(isDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius:
                  BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin, child: card);
    }
    return card;
  }

  /// Consistent text style constants for all transparent toolbox inputs
  static TextStyle get inputTextStyle => TextStyle(
        color: AppTheme.primaryColor.withValues(alpha: 0.85),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get hintTextStyle => TextStyle(
        color: AppTheme.primaryColor.withValues(alpha: 0.6),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  /// Consistent content padding for text fields
  static const EdgeInsets inputContentPadding =
      EdgeInsets.symmetric(horizontal: 4, vertical: 0);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;

    return SafeArea(
      child: Padding(
        padding: padding,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                // Dark mode: subtle glow effect for elevation
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 0),
                    ),
                  ]
                // Light mode: subtle shadows
                : [
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
            elevation: isDark ? 8 : 4,
            color: Colors.transparent,
            shadowColor: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                height: height,
                padding: const EdgeInsets.only(left: 16, right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        // Dark mode: more transparent with border for definition
                        ? [
                            barBase.withValues(alpha: 0.75),
                            barBase.withValues(alpha: 0.70),
                          ]
                        : [
                            barBase.withValues(alpha: 0.90),
                            barBase.withValues(alpha: 0.85),
                          ],
                  ),
                  // Dark mode: subtle border for definition
                  border: isDark
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.0,
                        )
                      : null,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal search content widget
class _SearchContent extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode focusNode;
  final Function(String) onSearchChanged;
  final String hintText;

  const _SearchContent({
    required this.searchController,
    required this.focusNode,
    required this.onSearchChanged,
    required this.hintText,
  });

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  bool _hasText = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.searchController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _onFocusChanged() {
    final hasFocus = widget.focusNode.hasFocus;
    if (hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search text field - optimized for fast response
        Expanded(
          child: TextField(
            controller: widget.searchController,
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 0,
              ),
              // Reduce intrinsic height for faster layout
              isDense: true,
            ),
            style: TextStyle(
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textInputAction: TextInputAction.search,
            // Faster keyboard appearance
            autofocus: false,
            enableInteractiveSelection: true,
            onChanged: widget.onSearchChanged,
            onTap: () {
              // Ensure focus is requested immediately on tap
              if (!widget.focusNode.hasFocus) {
                widget.focusNode.requestFocus();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Search/Close icon button (like HolyCow's send button)
        SizedBox(
          width: 64,
          height: 70,
          child: Opacity(
            opacity: 1.0,
            child: IconButton(
              onPressed: (_hasText || _hasFocus) ? _clearSearch : null,
              icon: Icon(
                (_hasText || _hasFocus) ? Icons.close : Icons.search,
                color: (_hasText || _hasFocus)
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.85),
                size: 28,
                shadows: (_hasText || _hasFocus)
                    ? [
                        Shadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ]
                    : null,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: (_hasText || _hasFocus)
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _clearSearch() {
    widget.searchController.clear();
    widget.onSearchChanged('');
    widget.focusNode.unfocus(); // Close keyboard
  }
}

/// Internal chat content widget
class _ChatContent extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final Function(String) onChanged;
  final String hintText;
  final bool canSend;
  // Namaste button support
  final VoidCallback? onNamaste;
  final bool showNamasteButton;

  const _ChatContent({
    required this.messageController,
    required this.focusNode,
    required this.onSend,
    required this.onChanged,
    required this.hintText,
    required this.canSend,
    this.onNamaste,
    this.showNamasteButton = false,
  });

  @override
  State<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<_ChatContent> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.messageController.text.trim().isNotEmpty;
    widget.messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged(widget.messageController.text);
  }

  void _handleNamasteTap() {
    // The animation is handled by _ChatNamasteButton
    // This just triggers the callback after animation completes
    widget.onNamaste?.call();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText || widget.canSend;
    // Show namaste when: no text, showNamasteButton is true, and callback is provided
    final showNamaste =
        !_hasText && widget.showNamasteButton && widget.onNamaste != null;

    return Row(
      children: [
        // Chat text field
        Expanded(
          child: TextField(
            controller: widget.messageController,
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 0,
              ),
              isDense: true,
            ),
            style: TextStyle(
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: null,
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            autofocus: false,
            enableInteractiveSelection: true,
            onSubmitted: canSend ? (_) => widget.onSend() : null,
            onTap: () {
              if (!widget.focusNode.hasFocus) {
                widget.focusNode.requestFocus();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Namaste button OR Send button (not both visible at same time)
        SizedBox(
          width: 48,
          height: 48,
          child: showNamaste
              // Show animated namaste button
              ? _ChatNamasteButton(onTap: _handleNamasteTap)
              // Show send button only
              : IconButton(
                  onPressed: canSend ? widget.onSend : null,
                  icon: Icon(
                    canSend
                        ? CupertinoIcons.paperplane_fill
                        : CupertinoIcons.paperplane,
                    color: canSend
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withValues(alpha: 0.3),
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Internal astrology chat content widget with cow icon and optional voice support
class _AstroChatContent extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final String hintText;
  final bool enableVoice;
  final VoidCallback? onMicPressed;

  const _AstroChatContent({
    required this.messageController,
    required this.focusNode,
    required this.onSend,
    required this.hintText,
    this.enableVoice = false,
    this.onMicPressed,
  });

  @override
  State<_AstroChatContent> createState() => _AstroChatContentState();
}

class _AstroChatContentState extends State<_AstroChatContent>
    with TickerProviderStateMixin {
  bool _hasText = false;
  late AnimationController _micAnimationController;
  late Animation<double> _micPulseAnimation;

  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_onTextChanged);

    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _micPulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    _micAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If voice is not enabled, use the simple layout
    if (!widget.enableVoice) {
      return _buildSimpleLayout();
    }

    // Voice-enabled layout with AudioInputService and AiChatProvider
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        return Consumer<AudioInputService>(
          builder: (context, audioService, _) {
            return _buildVoiceEnabledLayout(provider, audioService);
          },
        );
      },
    );
  }

  /// Simple layout without voice (original behavior)
  Widget _buildSimpleLayout() {
    return Row(
      children: [
        // Text input - expanded to fill available space
        Expanded(child: _buildTextField()),
        const SizedBox(width: 8),
        // Send button - HolyCow icon
        _buildCowSendButton(),
      ],
    );
  }

  /// Voice-enabled layout with recording states
  Widget _buildVoiceEnabledLayout(
      AiChatProvider provider, AudioInputService audioService) {
    final isRecording = audioService.isRecording;
    final isProcessing = audioService.isProcessing || provider.isStreaming;

    // Control animation based on recording state
    if (isRecording) {
      if (!_micAnimationController.isAnimating) {
        _micAnimationController.repeat(reverse: true);
      }
    } else {
      _micAnimationController.stop();
      _micAnimationController.reset();
    }

    // Determine unique key for animation state
    final stateKey = isRecording
        ? 'recording'
        : isProcessing
            ? 'processing'
            : 'normal';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Row(
        key: ValueKey(stateKey),
        children: [
          // Left section - Input, voice status, or processing status
          Expanded(
            child: _buildInputSection(audioService, isRecording, isProcessing),
          ),
          const SizedBox(width: 8),
          // Right section - Controls
          _buildControlsSection(
              provider, audioService, isRecording, isProcessing),
        ],
      ),
    );
  }

  /// Build the input section (left side)
  Widget _buildInputSection(
      AudioInputService audioService, bool isRecording, bool isProcessing) {
    if (isRecording) {
      return _buildVoiceStatusDisplay();
    } else if (isProcessing) {
      return _buildProcessingStatus();
    } else {
      return _buildTextField();
    }
  }

  /// Build processing status display when AI is generating
  Widget _buildProcessingStatus() {
    return Row(
      children: [
        PulsingDots(
          size: 5,
          color: AppTheme.astroBrown(
                  Theme.of(context).brightness == Brightness.dark)
              .withValues(alpha: 0.6),
        ),
        const SizedBox(width: 10),
        Text(
          'Generating',
          style: TextStyle(
            color: AppTheme.astroBrown(
                    Theme.of(context).brightness == Brightness.dark)
                .withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Build voice status display for recording state
  Widget _buildVoiceStatusDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated recording indicator - 3 pulsing bars
        _buildRecordingWaveAnimation(),
        const SizedBox(width: 12),
        Text(
          'Recording...',
          style: TextStyle(
            color: Colors.red[400],
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// Build minimal wave animation for recording indicator
  Widget _buildRecordingWaveAnimation() {
    return AnimatedBuilder(
      animation: _micPulseAnimation,
      builder: (context, child) {
        final progress = _micPulseAnimation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Stagger the animation for each bar
            final delay = index * 0.2;
            final animValue = ((progress - 0.9) / 0.2 + delay) % 1.0;
            final height = 8 + (animValue * 8); // 8-16px height

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: Colors.red[400],
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  /// Build text input field
  Widget _buildTextField() {
    return TextField(
      controller: widget.messageController,
      focusNode: widget.focusNode,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: AppTheme.primaryColor.withValues(alpha: 0.6),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 0,
        ),
        isDense: true,
      ),
      style: TextStyle(
        color: AppTheme.primaryColor.withValues(alpha: 0.85),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      textInputAction: TextInputAction.send,
      textCapitalization: TextCapitalization.sentences,
      autofocus: false,
      enableInteractiveSelection: true,
      onSubmitted: (_) {
        if (_hasText) {
          widget.onSend();
        }
      },
      onTap: () {
        if (!widget.focusNode.hasFocus) {
          widget.focusNode.requestFocus();
        }
      },
    );
  }

  /// Build the controls section (right side)
  Widget _buildControlsSection(AiChatProvider provider,
      AudioInputService audioService, bool isRecording, bool isProcessing) {
    if (isRecording) {
      return _buildRecordingControls(audioService);
    } else if (isProcessing) {
      return _buildStopButton(provider);
    } else {
      return _buildNormalControls(provider, audioService);
    }
  }

  /// Build controls for recording state
  Widget _buildRecordingControls(AudioInputService audioService) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cancel button
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            onPressed: () => _cancelVoiceRecording(audioService),
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
              foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Cancel recording',
          ),
        ),
        const SizedBox(width: 8),
        // Send button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _stopVoiceRecording(audioService),
            icon: const Icon(Icons.send, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.astroBrown(
                  Theme.of(context).brightness == Brightness.dark),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Send recording',
          ),
        ),
      ],
    );
  }

  /// Build normal controls (mic + cow send)
  Widget _buildNormalControls(
      AiChatProvider provider, AudioInputService audioService) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Microphone button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _startVoiceRecording(audioService, provider),
            icon: const Icon(Icons.mic, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppTheme.astroBrown(
                  Theme.of(context).brightness == Brightness.dark),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Voice message',
          ),
        ),
        // Cow send button
        _buildCowSendButton(),
      ],
    );
  }

  /// Build a subtle stop button for when AI is processing
  Widget _buildStopButton(AiChatProvider provider) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: GestureDetector(
          onTap: () {
            provider.stopStreaming();
            HapticFeedback.lightImpact();
          },
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.red.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }

  /// Build cow send button (used in both simple and voice-enabled layouts)
  Widget _buildCowSendButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _hasText
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onSend();
                }
              : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: Opacity(
              opacity: _hasText ? 1.0 : 0.4,
              child: Image.asset(
                'assets/images/cow1.png',
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => Icon(
                  CupertinoIcons.paperplane_fill,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Start voice recording
  Future<void> _startVoiceRecording(
      AudioInputService audioService, AiChatProvider provider) async {
    // Check if already recording or processing
    if (audioService.isRecording || audioService.isProcessing) {
      AppLogger.w('🎤 Already recording or processing',
          category: LogCategory.voice);
      return;
    }

    // Try to reset the service if there's an error from previous attempt
    if (audioService.hasError) {
      AppLogger.i('🎤 Resetting service due to previous error',
          category: LogCategory.voice);
      await audioService.resetService();
    }

    // Clear previous state and start fresh
    audioService.clearState();

    // Set up callback to update message when audio URL is uploaded
    audioService.setOnAudioUrlUploaded((audioUrl) {
      provider.updateLastVoiceMessageUrl(audioUrl);
    });

    // Set up callback for when upload is skipped (logged out user or failure)
    audioService.setOnAudioUploadSkipped(() {
      provider.markLastVoiceMessageAsLocalOnly();
    });

    // Start recording
    await audioService.startRecording(
      onResult: (AudioInputResult result) {
        // Send voice message
        _sendVoiceMessage(result, provider);
      },
      onTranscriptUpdate: (String transcript) {
        AppLogger.d('🎤 Live transcript update: "$transcript"',
            category: LogCategory.voice);
      },
    );
    HapticFeedback.lightImpact();
    widget.onMicPressed?.call();
  }

  /// Stop voice recording and send
  void _stopVoiceRecording(AudioInputService audioService) {
    audioService.stopRecording();
    HapticFeedback.mediumImpact();
  }

  /// Cancel voice recording without sending
  void _cancelVoiceRecording(AudioInputService audioService) {
    widget.messageController.clear();
    audioService.cancelRecording();
    AppLogger.i('🎤 Voice recording cancelled by user',
        category: LogCategory.voice);
    HapticFeedback.lightImpact();
  }

  /// Send voice message to AI chat
  void _sendVoiceMessage(AudioInputResult result, AiChatProvider provider) {
    widget.messageController.clear();

    // Send voice message to AI chat
    provider.sendVoiceMessage(
      transcript: result.transcript,
      localAudioPath: result.localAudioPath,
      audioUrl: result.audioUrl,
      durationInSeconds: result.durationInSeconds,
    );

    HapticFeedback.lightImpact();
  }
}

/// Animated namaste button for chat input with press → grow → fade animation
class _ChatNamasteButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ChatNamasteButton({required this.onTap});

  @override
  State<_ChatNamasteButton> createState() => _ChatNamasteButtonState();
}

class _ChatNamasteButtonState extends State<_ChatNamasteButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  Animation<double>? _opacityAnimation;
  bool _isAnimating = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    // Phase 1 (0-10%): Press down hard (shrink to 0.4x)
    // Phase 2 (10-40%): Grow to 1.8x
    // Phase 3 (40-100%): Stay at 1.8x while fading out
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.8)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.8, end: 1.8),
        weight: 60,
      ),
    ]).animate(_controller!);

    // Opacity: stays full until fade phase
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 65,
      ),
    ]).animate(_controller!);

    _isInitialized = true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isAnimating || !_isInitialized || _controller == null) return;

    setState(() => _isAnimating = true);
    HapticFeedback.lightImpact();

    // Call callback immediately so UI updates instantly
    widget.onTap();

    // Animation plays in parallel (purely visual)
    _controller!.forward(from: 0).then((_) {
      HapticFeedback.mediumImpact();
    });
  }

  Widget _buildNamasteIcon() {
    return Image.asset(
      'assets/icons/namaste.png',
      width: 36,
      height: 36,
      errorBuilder: (_, __, ___) => Text(
        '🙏',
        style: TextStyle(fontSize: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show static tappable button if not initialized yet
    if (!_isInitialized || _controller == null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: _buildNamasteIcon(),
        ),
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _controller!,
          builder: (context, child) {
            final scale = _scaleAnimation?.value ?? 1.0;
            final opacity = _opacityAnimation?.value ?? 1.0;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: _buildNamasteIcon(),
        ),
      ),
    );
  }
}
