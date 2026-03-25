import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/services/anonymous_message_service.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class SecretMessageSendComposer extends StatefulWidget {
  final String? recipientId;
  final String? recipientName;
  final String? slug;

  const SecretMessageSendComposer({
    super.key,
    this.recipientId,
    this.recipientName,
    this.slug,
  });

  @override
  State<SecretMessageSendComposer> createState() =>
      _SecretMessageSendComposerState();
}

class _SecretMessageSendComposerState extends State<SecretMessageSendComposer> {
  final _service = AnonymousMessageService();
  final _controller = TextEditingController();
  bool _isSending = false;
  bool _isLoadingRecipient = false;
  bool _sent = false;
  String? _recipientId;
  String? _recipientName;
  String? _slug;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recipientId = widget.recipientId;
    _recipientName = widget.recipientName;
    _slug = widget.slug;

    if (_recipientId == null && widget.slug != null) {
      _loadRecipientFromSlug(widget.slug!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecipientFromSlug(String slug) async {
    setState(() => _isLoadingRecipient = true);
    try {
      final data = await _service.getUserBySlug(slug);
      if (data == null) {
        setState(() {
          _errorMessage = 'This link isn’t valid.';
          _isLoadingRecipient = false;
        });
        return;
      }

      setState(() {
        _recipientId = data['uid'] as String?;
        _recipientName = data['name'] as String? ?? 'User';
        _isLoadingRecipient = false;
      });
    } catch (e) {
      _service.logError('Failed to resolve slug', e);
      setState(() {
        _errorMessage = 'This link isn’t valid.';
        _isLoadingRecipient = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending || _recipientId == null) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await _service.submitMessage(
        slug: _slug,
        recipientId: _slug == null ? _recipientId : null,
        text: text,
      );
      setState(() {
        _sent = true;
        _isSending = false;
      });
    } on FirebaseFunctionsException catch (e) {
      AppLogger.w('SecretMessageSendComposer: send failed',
          category: LogCategory.general,
          data: {'code': e.code, 'message': e.message, 'slug': _slug});
      setState(() {
        _errorMessage = _mapError(e.code);
        _isSending = false;
      });
    } catch (e, st) {
      AppLogger.w('SecretMessageSendComposer: send error',
          category: LogCategory.general,
          data: {'error': e.toString(), 'stackTrace': st.toString()});
      setState(() {
        _errorMessage = 'Couldn’t send. Try again.';
        _isSending = false;
      });
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid-argument':
        return 'Please enter a valid message.';
      case 'resource-exhausted':
        return 'Slow down — try again in a bit.';
      case 'not-found':
        return 'This link isn’t valid.';
      case 'failed-precondition':
        return 'You can’t message yourself.';
      default:
        return 'Couldn’t send. Try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _recipientName != null
        ? 'Send ${_recipientName!} something'
        : 'Send something';
    final subtext = 'It\'s anonymous.\n They won\'t know it\'s you.';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: AppTheme.primaryColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: IconThemeData(color: AppTheme.primaryColor),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Align(
            alignment: const Alignment(0, -0.2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _isLoadingRecipient
                  ? _buildLoading(context)
                  : _errorMessage != null && _recipientId == null
                      ? _buildError(context, _errorMessage!)
                      : _buildComposer(context, title, subtext),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final placeholder = Colors.black.withValues(alpha: 0.08);
    final padding = Responsive.value(
      context: context,
      mobile: 28.0,
      tablet: 32.0,
      desktop: 40.0,
    );
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPlaceholder(
                width: 200, height: 24, color: placeholder, radius: 8),
            const SizedBox(height: 12),
            _buildPlaceholder(
                width: 240, height: 16, color: placeholder, radius: 8),
            const SizedBox(height: 32),
            _buildPlaceholder(
              width: double.infinity,
              height: 120,
              color: placeholder,
              radius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder({
    required double width,
    required double height,
    required Color color,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final padding = Responsive.value(
      context: context,
      mobile: 28.0,
      tablet: 32.0,
      desktop: 40.0,
    );
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Text(
          message,
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context, String title, String subtext) {
    final padding = Responsive.value(
      context: context,
      mobile: 28.0,
      tablet: 32.0,
      desktop: 40.0,
    );
    final titleSize = Responsive.value(
      context: context,
      mobile: 26.0,
      tablet: 28.0,
      desktop: 30.0,
    );
    final subtextSize = Responsive.value(
      context: context,
      mobile: 15.0,
      tablet: 16.0,
      desktop: 17.0,
    );

    if (_sent) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
              const SizedBox(height: 20),
              Text(
                'Sent.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'They’ll see it in the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: subtextSize,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final canSend = _recipientId != null;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: Responsive.value(context: context, mobile: 24.0, tablet: 32.0, desktop: 40.0)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: Responsive.value(context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
          Text(
            subtext,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: subtextSize,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          SizedBox(height: Responsive.value(context: context, mobile: 32.0, tablet: 40.0, desktop: 48.0)),
          Material(
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.cardColor,
            child: TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 200,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Type your message',
                hintStyle:
                    TextStyle(color: AppTheme.textSecondaryColor.withValues(alpha: 0.8)),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                counterText: '',
                alignLabelWithHint: true,
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            SizedBox(height: Responsive.value(context: context, mobile: 10.0, tablet: 12.0)),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ],
          SizedBox(height: Responsive.value(context: context, mobile: 28.0, tablet: 32.0, desktop: 40.0)),
          Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              final surfaceColor = colorScheme.surface;
              final primaryColor = AppTheme.primaryColor;
              final buttonHeight = Responsive.value(
                context: context,
                mobile: 54.0,
                tablet: 56.0,
                desktop: 58.0,
              );
              return SizedBox(
                height: buttonHeight,
                child: Material(
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  color: canSend && !_isSending
                      ? surfaceColor
                      : surfaceColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(buttonHeight / 2),
                  child: InkWell(
                    onTap: (_isSending || !canSend) ? null : _send,
                    borderRadius: BorderRadius.circular(buttonHeight / 2),
                    child: Center(
                      child: _isSending
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            )
                          : Text(
                              'Send',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: canSend
                                    ? primaryColor
                                    : primaryColor.withValues(alpha: 0.6),
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: Responsive.value(context: context, mobile: 32.0, tablet: 40.0, desktop: 48.0)),
        ],
      ),
    );
  }
}
