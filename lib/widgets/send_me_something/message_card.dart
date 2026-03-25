import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _kDefaultHeading = 'SEND ME SOMETHING';
// NGL-style gradient: pink to purple
const Color _kHeaderStart = Color(0xFFE1306C);
const Color _kHeaderEnd = Color(0xFF833AB4);

/// NGL-style anonymous message card: gradient header (same as prompt card),
/// white body with message, attribution, and black Reply / Share story button.
class SecretMessageCard extends StatelessWidget {
  final String message;
  final String timeLabel;
  final String heading;
  final VoidCallback onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  /// When true (default), shows reply/time/delete row. When false, only gradient header + message (for detail page).
  final bool showBottomBar;
  /// When true (detail page), card uses proportional sections (gradient ~40%, message ~60%) and larger typography (NGL-style).
  final bool useDetailLayout;

  const SecretMessageCard({
    super.key,
    required this.message,
    required this.timeLabel,
    this.heading = _kDefaultHeading,
    required this.onShare,
    this.onDelete,
    this.onReport,
    this.onBlock,
    this.showBottomBar = true,
    this.useDetailLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width - (useDetailLayout ? size.width * 0.28 : 32);
    final cardRadius = useDetailLayout ? 28.0 : width * 0.06;
    final headerFont = useDetailLayout ? 16.0 : width * 0.034;
    final bodyFont = useDetailLayout ? 19.0 : width * 0.042;

    // NGL: gradient strip with min height in detail for proportion
    Widget gradientSection = Container(
      width: double.infinity,
      constraints: useDetailLayout
          ? const BoxConstraints(minHeight: 88)
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.12,
        vertical: useDetailLayout ? 28 : width * 0.04,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kHeaderStart, _kHeaderEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
      ),
      child: Center(
        child: Text(
          heading.trim().isEmpty ? _kDefaultHeading : heading.trim(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: headerFont,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );

    Widget messageSection = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.12,
        vertical: useDetailLayout ? 32 : width * 0.06,
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: bodyFont,
            height: 1.5,
            color: Colors.black.withValues(alpha: 0.88),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    return Container(
      margin: EdgeInsets.symmetric(vertical: useDetailLayout ? 0 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: useDetailLayout ? 24 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          gradientSection,
          messageSection,
          if (showBottomBar)
            // Reply left, time centered, delete right
            Padding(
              padding: EdgeInsets.fromLTRB(width * 0.08, 0, width * 0.08, width * 0.06),
              child: Row(
                children: [
                  _ReplyButton(onPressed: onShare, fontSize: bodyFont),
                  Expanded(
                    child: Text(
                      timeLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: bodyFont * 0.85,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.black.withValues(alpha: 0.5),
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (onReport != null || onBlock != null) ...[
                    if (onDelete != null) const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _showMenu(context),
                      icon: Icon(
                        CupertinoIcons.ellipsis,
                        color: Colors.black.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final actions = <Widget>[
      if (onReport != null)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop();
            onReport!();
          },
          isDestructiveAction: true,
          child: const Text('Report'),
        ),
      if (onBlock != null)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop();
            onBlock!();
          },
          isDestructiveAction: true,
          child: const Text('Block'),
        ),
    ];
    if (actions.isEmpty) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Anonymous message'),
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class _ReplyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double fontSize;

  const _ReplyButton({required this.onPressed, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final iconSize = fontSize + 2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/instagram.svg',
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.6),
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: fontSize * 0.5),
              Text(
                'Reply',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// NGL-style card for sharing to Instagram story: same look as [SecretMessageCard]
/// but fixed size for story (gradient header + message + Reply CTA).
class AnonymousMessageStoryCard extends StatelessWidget {
  final String heading;
  final String message;

  const AnonymousMessageStoryCard({
    super.key,
    this.heading = _kDefaultHeading,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B1F2E),
            Color(0xFF141827),
            Color(0xFF101421),
          ],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kHeaderStart, _kHeaderEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Text(
                  heading.trim().isEmpty
                      ? _kDefaultHeading
                      : heading.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 36, 40, 28),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.45,
                    color: Colors.black.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 36),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/instagram.svg',
                        width: 28,
                        height: 28,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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
}
