import 'package:flutter/material.dart';

class ProfileNavItem extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const ProfileNavItem({
    super.key,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
