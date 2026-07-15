import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';
import 'package:aurogram/features/ai_chat/presentation/widgets/ai_chat_input.dart';
import 'package:aurogram/features/ai_chat/presentation/widgets/ai_chat_message_list.dart';

/// Baba's in-place text chat — a frosted glass sheet that slides up OVER the
/// current screen instead of pushing a new route. This keeps the "Baba wraps
/// your whole app" feeling: you can type to him from anywhere without losing
/// where you are.
///
/// Deliberately reuses the exact same chat plumbing as the full page —
/// [AiChatProvider] (shared, app-scoped), [AiChatMessageList] and
/// [AiChatInput] — so voice and text share one conversation and one look. DRY.
class BabaChatPanel extends StatefulWidget {
  const BabaChatPanel({super.key, required this.onClose});

  /// Dismiss the sheet (tap scrim, close button, or back).
  final VoidCallback onClose;

  @override
  State<BabaChatPanel> createState() => _BabaChatPanelState();
}

class _BabaChatPanelState extends State<BabaChatPanel>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _entrance;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  AiChatProvider? _provider;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _slide = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider = Provider.of<AiChatProvider>(context, listen: false);
      // Start a fresh session only if there's nothing going — otherwise pick up
      // the ongoing conversation (e.g. one begun by voice).
      if (_provider!.messages.isEmpty) _provider!.startNewSession();
      _scrollToBottom(jump: true);
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(max,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _provider?.sendMessage(text);
    _messageController.clear();
    HapticFeedback.lightImpact();
    _scrollToBottom();
  }

  void _newChat() {
    _provider?.startNewSession();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    // Sheet takes most of the screen but stays clearly a floating overlay.
    final sheetHeight = media.size.height * 0.82;

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        return Stack(
          children: [
            // Scrim — tap anywhere outside to dismiss.
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35 * _fade.value),
                ),
              ),
            ),
            // The glass sheet.
            Positioned(
              left: 0,
              right: 0,
              bottom: -sheetHeight * (1 - _slide.value),
              height: sheetHeight,
              child: child!,
            ),
          ],
        );
      },
      child: _buildSheet(context, isDark, sheetHeight),
    );
  }

  Widget _buildSheet(BuildContext context, bool isDark, double height) {
    final surface = isDark ? AppTheme.cardDarkColor : Colors.white;
    // Lift the whole sheet content above the soft keyboard when it's up.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: isDark ? 0.82 : 0.90),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(child: _buildMessages(context)),
                SafeArea(
                  top: false,
                  child: AiChatInput(
                    messageController: _messageController,
                    focusNode: _focusNode,
                    onSendMessage: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Row(
        children: [
          // Grab handle + brand.
          Image.asset('assets/images/aurobhatt.png',
              width: 26, height: 26, fit: BoxFit.contain),
          const SizedBox(width: 8),
          Text(
            'Aurobhatt',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _newChat,
            icon: Icon(Icons.add_rounded,
                color: AppTheme.primaryColor, size: 22),
            tooltip: 'New chat',
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.primaryColor, size: 26),
            tooltip: 'Close chat',
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Consumer<AiChatProvider>(
        builder: (context, provider, _) {
          if (provider.messages.isEmpty) return _buildEmptyState();
          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: const [
              AiChatMessageList(),
              SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                color: AppTheme.primaryColor.withValues(alpha: 0.4), size: 34),
            const SizedBox(height: 12),
            Text(
              'Ask Aurobhatt anything',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
