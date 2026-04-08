import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';

typedef SizeChangedCallback = void Function(Size size);

/// Reports its child's size after layout. Used to cache post heights.
class SizeReportingWidget extends StatefulWidget {
  const SizeReportingWidget({
    super.key,
    required this.onSizeChange,
    required this.child,
  });

  final SizeChangedCallback onSizeChange;
  final Widget child;

  @override
  State<SizeReportingWidget> createState() => _SizeReportingWidgetState();
}

class _SizeReportingWidgetState extends State<SizeReportingWidget> {
  Size? _oldSize;
  int _reportCount = 0;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) return;
      if (!renderObject.hasSize || renderObject.debugNeedsLayout) return;
      final size = renderObject.size;
      if (size != _oldSize) {
        _oldSize = size;
        widget.onSizeChange(size);
        _reportCount += 1;
        if (kDebugMode && (_reportCount <= 2 || _reportCount % 10 == 0)) {
          AppLogger.d(
            'SizeReportingWidget: size changed',
            category: LogCategory.ui,
            data: {
              'w': size.width.toStringAsFixed(1),
              'h': size.height.toStringAsFixed(1),
              'count': _reportCount,
            },
          );
        }
      }
    });

    return widget.child;
  }
}
