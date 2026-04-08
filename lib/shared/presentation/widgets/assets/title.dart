import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/icon_transparent.png',
      fit: BoxFit.contain,
    );
  }
}
