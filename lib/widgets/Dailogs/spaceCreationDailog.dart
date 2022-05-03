import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yantra/pages/spaces/space.dart';
import 'package:yantra/services/databaseService.dart';

class SpaceCreationDailog extends StatefulWidget {
  final int selectedSpaceType;
  const SpaceCreationDailog({Key key, this.selectedSpaceType})
      : super(key: key);

  @override
  _SpaceCreationDailogState createState() => _SpaceCreationDailogState();
}

class _SpaceCreationDailogState extends State<SpaceCreationDailog> {
  double padding = 15;
  double avRadius = 10;
  bool active = false;
  bool nameRequired = false;
  TextEditingController _nameController = TextEditingController();

  onCreatePressed() async {
    if (_nameController.text.trim().isEmpty) {
      this.setState(() {
        nameRequired = true;
      });
      return;
    }
    this.setState(() {
      active = true;
    });

    var res = await DatabaseService()
        .createSpace(_nameController.text, widget.selectedSpaceType);

    Navigator.of(context, rootNavigator: true)
        .push(CupertinoPageRoute(builder: (context) {
      return SpaceBox(
        rid: res,
      );
    })).then((result) {
      Navigator.of(context).pop();
    });
  }

  String getTitle() {
    switch (widget.selectedSpaceType) {
      case 0:
        {
          return 'new open tribe';
        }
        break;
      case 1:
        {
          return 'new public tribe';
        }
        break;

      case 2:
        {
          return 'new private tribe';
        }
        break;
      default:
        {
          return 'new secret tribe';
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(padding),
      ),
      elevation: 10,
      backgroundColor: Colors.transparent,
      child: contentBox(context),
    );
  }

  contentBox(context) {
    return Container(
      padding: EdgeInsets.only(
          left: padding,
          top: avRadius + padding,
          right: padding,
          bottom: padding),
      margin: EdgeInsets.only(top: avRadius),
      decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          color: Colors.white,
          borderRadius: BorderRadius.circular(avRadius),
          boxShadow: [
            BoxShadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 2),
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            getTitle(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 20,
          ),
          if (nameRequired)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Space name is required",
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          CupertinoTextField(
            inputFormatters: [
              LengthLimitingTextInputFormatter(20),
            ],
            padding: EdgeInsets.all(10),
            controller: _nameController,
            placeholder: 'Name',
          ),
          SizedBox(
            height: 20,
          ),
          Align(
            alignment: Alignment.center,
            child: active
                ? Padding(
                    padding: EdgeInsets.all(14),
                    child: CupertinoActivityIndicator())
                : CupertinoButton(
                    borderRadius: BorderRadius.circular(10.0),
                    onPressed: () {
                      onCreatePressed();
                    },
                    child: Text(
                      "Create",
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    )),
          ),
        ],
      ),
    );
  }
}
