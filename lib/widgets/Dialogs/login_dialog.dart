import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/pages/login/login.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import '../assets/title.dart';

class LoginDialog extends StatelessWidget {
  const LoginDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {}, // Prevents taps on the dialog from dismissing it
          child: CupertinoAlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: Hero(
                    tag: 'app_logo',
                    child: AppTitle(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Login to unlock all features and interact with community!",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: AppTheme.textLightColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(CupertinoPageRoute(
                    builder: (context) => LoginPage(),
                  ));
                },
                isDestructiveAction: false,
                textStyle: TextStyle(color: AppTheme.primaryColor),
                child: const Text('Log In'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                isDefaultAction: false,
                textStyle: TextStyle(color: AppTheme.textSecondaryLightColor),
                child: const Text('Maybe Later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Usage example
void showLoginDialog(BuildContext context) {
  showCupertinoDialog(
    context: context,
    builder: (BuildContext context) => const LoginDialog(),
  );
}
