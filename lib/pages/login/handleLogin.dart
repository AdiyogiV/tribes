import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adiHouse/pages/initUser.dart';
import 'package:adiHouse/pages/login.dart';
import 'package:adiHouse/pages/spaces/inviteLandingPage.dart';
import 'package:adiHouse/services/authService.dart';

class HandleLogin extends StatefulWidget {
  final String space;
  final String invitee;

  HandleLogin({this.space, this.invitee});
  @override
  _HandleLoginState createState() => _HandleLoginState();
}

class _HandleLoginState extends State<HandleLogin> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, child) {
        if (auth.status == Status.Unauthenticated) {
          return LoginPage();
        }
        if (auth.status == Status.Uninitialized) {
          return InitUser();
        }
        return InviteLandingPage(
          space: widget.space,
          invitee: widget.invitee,
        );
      },
    );
  }
}
