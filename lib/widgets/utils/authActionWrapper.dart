import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/widgets/Dialogs/login_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class AuthActionWrapper extends StatelessWidget {
  final Widget child;
  final Future<dynamic> Function() onAction;

  const AuthActionWrapper({Key? key, required this.child, required this.onAction}) : super(key: key);

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
