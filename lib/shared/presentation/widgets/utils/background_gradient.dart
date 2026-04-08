import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

class BackgroundGradient {
  static BoxDecoration build(BuildContext context) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppTheme.scaffoldLightColor,
          AppTheme.scaffoldLightColor.withValues(alpha: 0.3)
        ],
        begin: const FractionalOffset(0.0, 0.0),
        end: const FractionalOffset(0.0, 1),
        stops: const [0, 1],
        tileMode: TileMode.mirror,
      ),
    );
  }
}
