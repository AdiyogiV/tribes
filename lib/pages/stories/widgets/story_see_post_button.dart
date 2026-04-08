import 'package:flutter/material.dart';
import 'package:aurogram/pages/content/thread_view.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Centered "See post" button overlaid on story cards that originated from a post.
/// Visible/invisible toggled by the parent via [isVisible].
class StorySeePostButton extends StatelessWidget {
  final String postId;
  final bool isVisible;
  final VoidCallback onHide;

  const StorySeePostButton({
    super.key,
    required this.postId,
    required this.isVisible,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Center(
          child: GestureDetector(
            onTap: () async {
              onHide();
              await Future.delayed(const Duration(milliseconds: 100));
              if (context.mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ThreadView(postId: postId),
                  ),
                );
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.article_outlined, color: Colors.black87, size: 18),
                  SizedBox(width: AppDimensions.spacingSm),
                  Text(
                    'See post',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
