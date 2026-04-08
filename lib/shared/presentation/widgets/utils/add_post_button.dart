import 'package:aurogram/features/spaces/presentation/pages/gram_selection_page.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AddPostButton extends StatelessWidget {
  final BuildContext context;

  const AddPostButton({
    super.key,
    required this.context,
  });

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
