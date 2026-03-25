import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

/// Full-screen avatar viewer with zoom and pan capabilities
class FullScreenAvatarViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String name;

  const FullScreenAvatarViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.name,
  });

  @override
  State<FullScreenAvatarViewer> createState() => _FullScreenAvatarViewerState();

  /// Show the fullscreen avatar viewer
  static void show(
    BuildContext context, {
    required String heroTag,
    required String imageUrl,
    required String name,
  }) {
    if (imageUrl.isEmpty) return;

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenAvatarViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
          name: name,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _FullScreenAvatarViewerState extends State<FullScreenAvatarViewer> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFD4A574);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isZoomed)
                    Flexible(
                      child: Text(
                        widget.name,
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: primaryColor, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionUpdate: (details) {
                  setState(() {
                    _isZoomed =
                        _transformationController.value.getMaxScaleOnAxis() >
                            1.0;
                  });
                },
                child: Hero(
                  tag: widget.heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      fit: BoxFit.contain,
                      memCacheWidth:
                          (MediaQuery.of(context).size.width * 3).toInt(),
                      memCacheHeight:
                          (MediaQuery.of(context).size.height * 3).toInt(),
                      placeholder: (context, url) => ShimmerImagePlaceholder(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Icon(
                            Icons.person,
                            size: 100,
                            color: Color(0x80D4A574),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
