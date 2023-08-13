import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tribes/pages/login.dart';
import 'package:tribes/pages/login/handleLogin.dart';
import 'package:tribes/pages/spaces/space.dart';
import 'package:tribes/services/authService.dart';
import 'package:tribes/services/databaseService.dart';
import 'package:tribes/widgets/previewBoxes/userPreviewBox.dart';
import 'package:tribes/widgets/previewBoxes/spacePreviewBox.dart';

class InviteLandingPage extends StatefulWidget {
  final String? space;
  final String? invitee;

  InviteLandingPage({this.space, this.invitee});

  @override
  _InviteLandingPageState createState() => _InviteLandingPageState();
}

class _InviteLandingPageState extends State<InviteLandingPage> {
  User? user = FirebaseAuth.instance.currentUser;
  @override
  void initState() {
    super.initState();
  }

  requestLogin() async {
    await showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            content: Text("Please Login to Continue"),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return LoginPage();
                    }));
                  },
                  child: Text(
                    'Login',
                    style: TextStyle(
                        color: CupertinoColors.destructiveRed,
                        fontWeight: FontWeight.w400),
                  )),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.w400),
                  ))
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, child) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              if (auth.status != Status.Authenticated) {
                Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (BuildContext context) {
                  return HandleLogin(
                    space: widget.space,
                    invitee: widget.invitee,
                  );
                }));
                return;
              }
              bool res = await DatabaseService()
                  .addSpaceMember(widget.space!, user!.uid);
              if (res) {
                Navigator.of(context, rootNavigator: true)
                    .push(CupertinoPageRoute(builder: (context) {
                  return SpaceBox(
                    rid: widget.space,
                  );
                })).then((result) {
                  Navigator.of(context).pop();
                });
              }
            },
            backgroundColor: CupertinoTheme.of(context).primaryColor,
            icon: Icon(Icons.check),
            label: Text('ACCEPT'),
          ),
          appBar: CupertinoNavigationBar(
            middle: Text(
              'tribes',
              style: TextStyle(fontWeight: FontWeight.w300),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                    width: MediaQuery.of(context).size.width / 3,
                    child: UserPreview(
                      uid: widget.invitee,
                      showName: true,
                    )),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text('invited you\n to join the space',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: CupertinoColors.black,
                        shadows: [
                          Shadow(
                            blurRadius: 1,
                            color: Colors.white,
                            offset: Offset(0, 0),
                          ),
                        ],
                      )),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                      width: MediaQuery.of(context).size.width / 2,
                      child: SpacePreviewBox(
                        space: widget.space!,
                      )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
