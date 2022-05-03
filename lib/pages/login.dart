import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yantra/services/authService.dart';
import 'package:country_code_picker/country_code_picker.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = new GlobalKey<FormState>();
  TextEditingController _myPhoneField = TextEditingController();
  TextEditingController _countryCode = TextEditingController(text: '+91');
  String phoneNo, verificationId, smsCode;
  bool codeSent = false;

  @override
  void dispose() {
    super.dispose();
    _myPhoneField?.dispose();
    _countryCode?.dispose();
  }

  onSendOTPPressed() {
    if (_myPhoneField.text.isEmpty) {
      showCupertinoDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              content: Text('Please enter a valid phone'
                  ' number'),
              actions: <Widget>[
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Try Again'))
              ],
            );
          });
    } else {
      verifyPhone(phoneNo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, child) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              codeSent
                  ? Provider.of<AuthService>(context, listen: false)
                      .signInWithOTP(smsCode, verificationId)
                  : onSendOTPPressed();
            },
            backgroundColor: CupertinoTheme.of(context).primaryColor,
            icon: Icon(Icons.arrow_right_alt),
            label: codeSent ? Text('LOGIN') : Text('SEND OTP'),
          ),
          body: Form(
              key: formKey,
              child: codeSent
                  ? Padding(
                      padding: EdgeInsets.only(left: 20.0, right: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              "OTP sent to $phoneNo",
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: CupertinoTextField(
                              keyboardType: TextInputType.phone,
                              padding: EdgeInsets.all(12),
                              placeholder: 'Enter OTP',
                              onChanged: (val) {
                                setState(() {
                                  this.smsCode = val;
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: CupertinoButton(
                                child:
                                    Center(child: Text('Use Another Number')),
                                onPressed: () {
                                  this.setState(() {
                                    phoneNo = '';
                                    codeSent = false;
                                    _myPhoneField.text = '';
                                  });
                                }),
                          )
                        ],
                      ))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                            padding: const EdgeInsets.only(
                                left: 25.0, right: 25, bottom: 10),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: CupertinoButton.filled(
                                    disabledColor: CupertinoColors.white,
                                    padding:
                                        EdgeInsets.only(left: 10, right: 10),
                                    onPressed: () {},
                                    child: CountryCodePicker(
                                      textStyle: TextStyle(
                                        fontSize: 15,
                                      ),
                                      onChanged: (code) {
                                        _countryCode.text = code.toString();
                                      },

                                      textOverflow: TextOverflow.ellipsis,
                                      // Initial selection and favorite can be one of code ('IT') OR dial_code('+39')
                                      initialSelection: '+91',
                                      favorite: ['+91', '+33', '+86'],
                                      // optional. Shows only country name and flag
                                      showCountryOnly: false,
                                      // optional. Shows only country name and flag when popup is closed.
                                      showOnlyCountryWhenClosed: true,
                                    ),
                                  ),
                                )
                              ],
                            )),
                        Row(
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: EdgeInsets.only(left: 25.0),
                                child: CupertinoTextField(
                                  readOnly: true,
                                  padding: EdgeInsets.all(12),
                                  controller: _countryCode,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 7,
                              child: Padding(
                                padding: EdgeInsets.only(left: 5, right: 25.0),
                                child: CupertinoTextField(
                                  padding: EdgeInsets.all(12),
                                  controller: _myPhoneField,
                                  placeholder: 'Enter Phone Number',
                                  keyboardType: TextInputType.phone,
                                  onChanged: (val) {
                                    setState(() {
                                      this.phoneNo = _countryCode.text + '$val';
                                    });
                                  },
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    )),
        );
      },
    );
  }

  Future<void> verifyPhone(phoneNo) async {
    final PhoneVerificationCompleted verified = (authResult) async {
      Provider.of<AuthService>(context, listen: false).signIn(authResult);
    };

    final PhoneVerificationFailed verificationfailed =
        (Exception authException) {
      showCupertinoDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              content: Text(authException.toString()),
              actions: <Widget>[
                CupertinoButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Try Again'))
              ],
            );
          });
    };

    final PhoneCodeSent smsSent = (String verId, [int forceResend]) {
      this.verificationId = verId;
      setState(() {
        this.codeSent = true;
      });
    };

    final PhoneCodeAutoRetrievalTimeout autoTimeout = (String verId) {
      this.verificationId = verId;
    };

    await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNo,
        timeout: const Duration(seconds: 10),
        verificationCompleted: verified,
        verificationFailed: verificationfailed,
        codeSent: smsSent,
        codeAutoRetrievalTimeout: autoTimeout);
  }
}
