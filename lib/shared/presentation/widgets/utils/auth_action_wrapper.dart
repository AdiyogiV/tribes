import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class AuthActionWrapper extends StatelessWidget {
  final Widget child;
  final Future<dynamic> Function() onAction;

  const AuthActionWrapper({super.key, required this.child, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        return GestureDetector(
          onTap: () async {
            if (auth.status == Status.Authenticated) {
              await onAction();
            } else {
              showLoginBottomSheet(context);
            }
          },
          child: child,
        );
      },
    );
  }
}
