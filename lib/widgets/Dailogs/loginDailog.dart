import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yantra/pages/login.dart';
import 'package:yantra/widgets/assets/title.dart';

class LoginDailog extends StatefulWidget {
  const LoginDailog({Key key}) : super(key: key);

  @override
  _LoginDailogState createState() => _LoginDailogState();
}

class _LoginDailogState extends State<LoginDailog> {
  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Material(
                borderRadius: BorderRadius.circular(10),
                elevation: 5,
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 100,
                )),
          ),
          AppTitle(),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Login to Continue", style: TextStyle(fontWeight: FontWeight.w300, fontSize: 16),),
          ),
        ],
      ),
      actions: <Widget>[
        FlatButton(
            onPressed: () {
              Navigator.of(context).push(CupertinoPageRoute(builder: (context) {
                return LoginPage();
              }));
            },
            child: Text(
              'Login',
              style: TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontWeight: FontWeight.w400),
            )),
        FlatButton(
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
    ;
  }
}
