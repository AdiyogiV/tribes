import 'package:aurogram/services/post_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportDialog extends StatefulWidget {
  final String? post;
  const ReportDialog({Key? key, this.post}) : super(key: key);

  @override
  ReportDialogState createState() => ReportDialogState();
}

class ReportDialogState extends State<ReportDialog> {
  final TextEditingController _controller = TextEditingController();
  User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text('Report Post', style: TextStyle(color: AppTheme.textLightColor)),
      backgroundColor: AppTheme.scaffoldLightColor,
      content: TextField(
        controller: _controller,
        maxLines: null,
        decoration: InputDecoration(
          labelText: 'Enter reason',
          labelStyle: TextStyle(color: AppTheme.textSecondaryLightColor),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primaryLightColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primaryLightColor),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel', style: TextStyle(color: AppTheme.primaryColor)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text('Report', style: TextStyle(color: AppTheme.errorColor)),
          onPressed: () {
            PostService().reportPost(widget.post!, _controller.text);
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: AppTheme.scaffoldLightColor,
                  title: Text('Reported',
                      style: TextStyle(color: AppTheme.textLightColor)),
                  content: Text(
                      'Thank you for reporting this post. It will be reviewed by our team within 24 hrs.\n\nIt is our priority to keep Aurogram free of objectionable content and your support for the same is appreciated',
                      style: TextStyle(color: AppTheme.textLightColor)),
                  actions: <Widget>[
                    TextButton(
                      child: Text('OK',
                          style: TextStyle(color: AppTheme.primaryColor)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
