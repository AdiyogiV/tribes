import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Custom swipeable message widget with smooth animation for reply gesture
class SwipeableMessage extends StatefulWidget {
  final Widget child;
  final bool isOwnMessage;
  final VoidCallback onSwipe;

  const SwipeableMessage({
    super.key,
    required this.child,
    required this.isOwnMessage,
    required this.onSwipe,
  });

  @override
  State<SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<SwipeableMessage>
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

          // Trigger haptic at threshold (mobile only)
          if (!_triggered && _dragOffset.abs() >= _triggerThreshold) {
            _triggered = true;
            if (!kIsWeb) HapticFeedback.mediumImpact();
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
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: iconOpacity,
                  child: Transform.scale(
                    scale: iconScale,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.reply_rounded,
                        color: AppTheme.primaryColor,
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
