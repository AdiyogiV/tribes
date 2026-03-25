import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// A simple widget that displays a user's aura score (like Snapscore)
class AuraBadge extends StatelessWidget {
  final int auraScore;
  final double fontSize;
  final Color? color;

  const AuraBadge({
    super.key,
    required this.auraScore,
    this.fontSize = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.bolt,
          color: color ?? AppTheme.primaryColor,
          size: fontSize * 1.2,
        ),
        SizedBox(width: 4),
        Text(
          auraScore.toString(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color ??
                (isDark ? AppTheme.textDarkColor : AppTheme.textLightColor),
          ),
        ),
      ],
    );
  }
}

/// A simple aura score display card (like Snapscore)
class AuraScoreCard extends StatelessWidget {
  final int auraScore;
  final VoidCallback? onTap;

  const AuraScoreCard({
    super.key,
    required this.auraScore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      elevation: isDark ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AppTheme.primaryColor.withOpacity(0.15),
                      AppTheme.primaryColor.withOpacity(0.08),
                    ]
                  : [
                      AppTheme.primaryColor.withOpacity(0.08),
                      AppTheme.primaryColor.withOpacity(0.03),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : AppTheme.primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bolt,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Auro Score',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppTheme.textSecondaryDarkColor
                          : AppTheme.textSecondaryLightColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    auraScore.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              Spacer(),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppTheme.textSecondaryDarkColor
                      : AppTheme.textSecondaryLightColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact aura score display for use in lists or small spaces
class AuraScoreCompact extends StatelessWidget {
  final int auraScore;

  const AuraScoreCompact({
    super.key,
    required this.auraScore,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt,
            color: AppTheme.primaryColor,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            auraScore.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDarkColor : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
