import 'dart:io' as di;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:image_picker/image_picker.dart';
import 'package:adiHouse/services/databaseService.dart';

class ItemCreationDailog extends StatefulWidget {
  final String space;
  const ItemCreationDailog({Key key, this.space}) : super(key: key);

  @override
  _ItemCreationDailogState createState() => _ItemCreationDailogState();
}

class _ItemCreationDailogState extends State<ItemCreationDailog> {
  double padding = 15;
  double avRadius = 10;
  bool active = false;
  bool nameRequired = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _priceController = TextEditingController();
  di.File itemImage;

  void _onImageButtonPressed() async {
    try {
      final pickedFile =
          await ImagePicker().getImage(source: ImageSource.gallery);
      itemImage = di.File(pickedFile.path);
      setState(() {});
    } catch (e) {
      setState(() {});
    }
  }

  onCreatePressed() async {
    if (_nameController.text.trim().isEmpty) {
      this.setState(() {
        nameRequired = true;
      });
      return;
    }

    var res = await DatabaseService().createItem(_nameController.text,
        _priceController.text, itemImage.path, widget.space);
    setState(() {});
    Navigator.of(context).pop();
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
          SizedBox(
            height: 20,
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Material(
              elevation: 5,
              shape: CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                onTap: () {
                  _onImageButtonPressed();
                },
                child: Container(
                  width: MediaQuery.of(context).size.width / 4,
                  height: MediaQuery.of(context).size.width / 4,
                  child: (itemImage != null)
                      ? Image.file(
                          itemImage,
                          fit: BoxFit.cover,
                        )
                      : Image.asset('assets/images/user.png'),
                ),
              ),
            ),
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
            padding: EdgeInsets.all(10),
            controller: _nameController,
            placeholder: 'Name',
          ),
          CupertinoTextField(
            padding: EdgeInsets.all(10),
            controller: _priceController,
            placeholder: 'Price',
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
