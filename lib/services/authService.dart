import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:adiHouse/services/databaseService.dart';

enum Status {
  Undetermined,
  Uninitialized,
  Authenticated,
  Authenticating,
  Unauthenticated
}

class AuthService extends ChangeNotifier {
  FirebaseAuth _auth = FirebaseAuth.instance;
  User _user;
  Status _status = Status.Undetermined;

  AuthService.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_authStateChanges);
  }

  Status get status => _status;
  User get user => _user;

  String userId = '';
  bool isUserNew = false;

  signOut() async {
    FirebaseAuth.instance.signOut();
    _status = Status.Unauthenticated;
    notifyListeners();
  }

  signIn(AuthCredential authCreds) async {
    try {
      _status = Status.Authenticating;
      await FirebaseAuth.instance
          .signInWithCredential(authCreds)
          .then((value) => notifyListeners());
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
    }
  }

  signInWithOTP(smsCode, verId) {
    AuthCredential authCreds =
        PhoneAuthProvider.credential(verificationId: verId, smsCode: smsCode);
    signIn(authCreds);
  }

  handleStatus(isUserNew) async {
    if (isUserNew) {
      _status = Status.Uninitialized;
    } else {
      _status = Status.Authenticated;
    }
    notifyListeners();
  }

  Future<void> _authStateChanges(User firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      userId = _user.uid;
      isUserNew = await DatabaseService(uid: userId).checkRegistration();
      handleStatus(isUserNew);
    }
    notifyListeners();
  }
}
