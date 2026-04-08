import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/send_me_something/message_card.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Full-screen view of a single anonymous message (NGL-style).
/// App header, scaffold background, centered card, black pill Reply button.
class AnonymousMessageDetailPage extends StatelessWidget {
  final String heading;
  final String message;
  final String timeLabel;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const AnonymousMessageDetailPage({
    super.key,
    required this.heading,
    required this.message,
    required this.timeLabel,
    required this.onShare,
    required this.onDelete,
  });

  // NGL: card ~78% width, generous padding
  static const double _cardMaxWidthFraction = 0.78;
  static const double _replyHorizontalPaddingPercent = 0.12;
  static const double _replyBottomPadding = 28;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cardMaxWidth = size.width * _cardMaxWidthFraction;
    final replyHorizontalPadding = size.width * _replyHorizontalPaddingPercent;

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
        title: Text(
          'message',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: AppTheme.primaryColor, size: 22),
            onPressed: onDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: (size.width - cardMaxWidth) / 2,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    child: SecretMessageCard(
                      heading: heading,
                      message: message,
                      timeLabel: timeLabel,
                      onShare: onShare,
                      showBottomBar: false,
                      useDetailLayout: true,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                replyHorizontalPadding,
                16,
                replyHorizontalPadding,
                _replyBottomPadding + MediaQuery.paddingOf(context).bottom,
              ),
              child: _NglReplyButton(onPressed: onShare),
            ),
          ],
        ),
      ),
    );
  }
}

/// NGL-style reply: solid black, pill-shaped, white Instagram icon + "reply".
class _NglReplyButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _NglReplyButton({required this.onPressed});

  static const double _h = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _h,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(_h / 2),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_h / 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/instagram.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMdSm),
              Text(
                'reply',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
