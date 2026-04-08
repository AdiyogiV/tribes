import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

class SecretMessageShareCard extends StatelessWidget {
  final String message;
  final String shareLink;

  const SecretMessageShareCard({
    super.key,
    required this.message,
    required this.shareLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 720,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.15),
            AppTheme.cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aurogram',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Someone said:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            message,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          Divider(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            'Send me an anonymous message',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSmMd),
          Text(
            'Add a link sticker on your story (link is not clickable from the card).',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            shareLink,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class AnonymousLinkShareCard extends StatelessWidget {
  final String shareLink;
  final String? avatarUrl;
  final String? heading;
  final String? subheading;

  const AnonymousLinkShareCard({
    super.key,
    required this.shareLink,
    this.avatarUrl,
    this.heading,
    this.subheading,
  });

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6A2BD9);
    return Container(
      width: 1080,
      height: 1920,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
      child: Column(
        children: [
          const SizedBox(height: 80),
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 52),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: purple,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      child: Text(
                        heading?.trim().isNotEmpty == true
                            ? heading!.trim()
                            : 'SEND ME SOMETHING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 26, 36, 34),
                      child: Text(
                        subheading?.trim().isNotEmpty == true
                            ? subheading!.trim()
                            : 'send me something, anonymously',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: purple,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Icon(
                          Icons.person,
                          color: purple,
                          size: 28,
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, size: 22, color: purple),
                const SizedBox(width: AppDimensions.spacingMd),
                Text(
                  'Paste your LINK here',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: purple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMdLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_upward_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 24),
              const SizedBox(width: AppDimensions.spacingMdLg),
              Icon(Icons.arrow_upward_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 24),
              const SizedBox(width: AppDimensions.spacingMdLg),
              Icon(Icons.arrow_upward_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 24),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icon_transparent.png',
                width: 36,
                height: 36,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Text(
                'Aurogram',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
