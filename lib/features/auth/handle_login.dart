import 'package:aurogram/pages/helpers/flash.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/features/auth/init_user.dart';
import 'package:aurogram/features/auth/login.dart';
import 'package:aurogram/features/spaces/presentation/pages/invite_landing_page.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';

class HandleLogin extends StatefulWidget {
  final String? space;
  final String? invitee;

  const HandleLogin({super.key, this.space, this.invitee});
  @override
  HandleLoginState createState() => HandleLoginState();
}

class HandleLoginState extends State<HandleLogin> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, child) {
        AppLogger.i('🔄 HandleLogin build() - status: ${auth.status}, userId: ${auth.userId}, isUserNew: ${auth.isUserNew}',
            category: LogCategory.ui);
        
        switch (auth.status) {
          case Status.Unauthenticated:
            AppLogger.i('🔄 Showing LoginPage',
                category: LogCategory.ui);
            return LoginPage();
          case Status.Uninitialized:
            AppLogger.i('🔄 Showing InitUser page',
                category: LogCategory.ui);
            return InitUser();
          case Status.Authenticating:
          case Status.Undetermined:
            AppLogger.i('🔄 Showing FlashScreen (loading) - status: ${auth.status}',
                category: LogCategory.ui);
            return FlashScreen();
          case Status.Authenticated:
            AppLogger.i('🔄 Showing InviteLandingPage',
                category: LogCategory.ui);
            return InviteLandingPage(
              space: widget.space,
              invitee: widget.invitee,
            );
        }
      },
    );
  }
}
