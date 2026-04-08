import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Banner card for accepting/declining a follow request from another user.
class ProfileFollowRequestBanner extends StatelessWidget {
  final String userName;
  final bool isAcceptingRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const ProfileFollowRequestBanner({
    super.key,
    required this.userName,
    required this.isAcceptingRequest,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final displayName = userName.isNotEmpty ? userName : 'Someone';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppHeaderStyle.contentHorizontalPadding,
      ),
      child: TransparentToolbox.buildCard(
        context: context,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label
              Text(
                'FOLLOW REQUEST',
                style: AppTheme.cardLabelStyle,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              // Subtitle
              Text(
                '$displayName has requested to follow you',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              // Action buttons
              Row(
                children: [
                  // Accept button
                  Expanded(
                    child: GestureDetector(
                      onTap: isAcceptingRequest ? null : onAccept,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Center(
                          child: isAcceptingRequest
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CupertinoActivityIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Accept',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMdSm),
                  // Decline button
                  Expanded(
                    child: GestureDetector(
                      onTap: isAcceptingRequest ? null : onDecline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          border: Border.all(
                            color: c.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
