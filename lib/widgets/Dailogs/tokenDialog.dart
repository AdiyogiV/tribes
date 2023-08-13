import 'dart:io' as di;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tribes/services/databaseService.dart';

class TokenDialog extends StatefulWidget {
  final String? item;
  const TokenDialog({Key? key, this.item}) : super(key: key);

  @override
  _TokenDialogState createState() => _TokenDialogState();
}

class _TokenDialogState extends State<TokenDialog> {
  double padding = 15;
  double avRadius = 10;
  bool active = false;
  bool nameRequired = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _priceController = TextEditingController();
  di.File? itemImage;
  String name = '';
  String displayPicture = '';
  File? displayPicFile;
  String price = '';
  User? user = FirebaseAuth.instance.currentUser;
  String address = '';

  @override
  void initState() {
    super.initState();
    getItem();
  }

  getItem() async {
    DocumentSnapshot space = await DatabaseService().getItem(widget.item!);
    name = space['name'];
    displayPicture = space['image'];
    price = space['price'];
    setState(() {});
    displayPicFile =
        await DefaultCacheManager().getSingleFile(displayPicture);
    address = generateRandomString(20);
    setState(() {});
  }

  String generateRandomString(int len) {
    var r = Random();
    return String.fromCharCodes(
        List.generate(len, (index) => r.nextInt(33) + 89));
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

  getImage() {
    return Material(
      borderRadius: BorderRadius.circular(7.0),
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: MediaQuery.of(context).size.width / 4,
          height: MediaQuery.of(context).size.width / 4,
          child: (displayPicFile != null)
              ? Image.file(
                  displayPicFile!,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  'assets/images/space.jpg',
                  fit: BoxFit.cover,
                ),
        ),
      ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            height: 20,
          ),
          Padding(padding: const EdgeInsets.all(10.0), child: getImage()),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 25,
                  fontWeight: FontWeight.w200),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Text(
              'Blockchain : Mumbai [Polygon testnet]',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w300),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Text(
              'Contract Address : $address}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w300),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Align(
              alignment: Alignment.center,
              child: active
                  ? Text(
                      'Prototyping Ends Here\nThank you!',
                      style: TextStyle(
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : CupertinoButton(
                      borderRadius: BorderRadius.circular(10.0),
                      color: Colors.red,
                      onPressed: () async {
                        active = true;
                        this.setState(() {});
                      },
                      child: Text(
                        "Sell",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ))
        ],
      ),
    );
  }
}
