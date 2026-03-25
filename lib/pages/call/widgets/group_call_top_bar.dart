import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GroupCallTopBar extends StatelessWidget {
  final String spaceName;
  final bool isJoining;
  final int participantsCount;
  final int connectionQuality;
  final ValueListenable<int> callDuration;
  final String Function(int seconds) formatDuration;
  final VoidCallback onLeave;

  const GroupCallTopBar({
    super.key,
    required this.spaceName,
    required this.isJoining,
    required this.participantsCount,
    required this.connectionQuality,
    required this.callDuration,
    required this.formatDuration,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onLeave,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spaceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  ValueListenableBuilder<int>(
                    valueListenable: callDuration,
                    builder: (context, duration, _) {
                      return Row(
                        children: [
                          if (!isJoining) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            isJoining
                                ? 'Joining...'
                                : formatDuration(duration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            if (!isJoining)
              _ConnectionQualityIndicator(quality: connectionQuality),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$participantsCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionQualityIndicator extends StatelessWidget {
  final int quality;

  const _ConnectionQualityIndicator({required this.quality});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String tooltip;

    if (quality >= 4) {
      color = const Color(0xFF4CAF50);
      icon = Icons.signal_cellular_4_bar;
      tooltip = 'Excellent connection';
    } else if (quality >= 3) {
      color = const Color(0xFF8BC34A);
      icon = Icons.signal_cellular_alt;
      tooltip = 'Good connection';
    } else if (quality >= 2) {
      color = const Color(0xFFFFC107);
      icon = Icons.signal_cellular_alt_2_bar;
      tooltip = 'Fair connection';
    } else {
      color = const Color(0xFFFF5722);
      icon = Icons.signal_cellular_alt_1_bar;
      tooltip = 'Poor connection';
    }

    final indicator = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );

    if (kIsWeb) {
      return indicator;
    }

    return Tooltip(
      message: tooltip,
      child: indicator,
    );
  }
}
