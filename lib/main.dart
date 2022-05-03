import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yantra/tabs.dart';
import 'package:yantra/services/authService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //return Container(color: Colors.yellow,);

    return MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => AuthService.instance(),
          )
        ],
        child: CupertinoApp(
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            theme: CupertinoThemeData(
              brightness: Brightness.light,
              primaryColor: Colors.indigo[900],
              scaffoldBackgroundColor: Colors.indigo[100],
            ),
            home: TabHandler()));
  }
}
