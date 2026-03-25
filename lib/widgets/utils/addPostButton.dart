import 'package:aurogram/pages/helpers/gramSelectionPage.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/Dialogs/login_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AddPostButton extends StatelessWidget {
  final BuildContext context;

  const AddPostButton({
    Key? key,
    required this.context,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: FloatingActionButton(
        onPressed: () {
          final User? user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            showLoginBottomSheet(context);
            return;
          }
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              builder: (context) => GramSelectionPage(),
            ),
          );
        },
        elevation: 2,
        backgroundColor: AppTheme.primaryColor,
        heroTag: UniqueKey(),
        child: Icon(
          CupertinoIcons.add,
          color: AppTheme.textDarkColor,
        ),
      ),
    );
  }
}
